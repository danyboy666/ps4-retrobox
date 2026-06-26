/*
 * fb_display - Minimal framebuffer image viewer for PS4 RetroBox
 * Displays pre-scaled PNG images on /dev/fb0 with correct stride handling.
 * Compile: gcc -O2 -o fb_display fb_display.c -lpng -ljpeg
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <jpeglib.h>
#include <png.h>

static int fb_w = 1920, fb_h = 1080, stride = 7680;

static void read_fb_geometry(void) {
    FILE *f;
    f = fopen("/sys/class/graphics/fb0/virtual_size", "r");
    if (f) { fscanf(f, "%d,%d", &fb_w, &fb_h); fclose(f); }
    f = fopen("/sys/class/graphics/fb0/stride", "r");
    if (f) { fscanf(f, "%d", &stride); fclose(f); }
    else stride = fb_w * 4;
}

static int load_png(const char *path, unsigned char **out, int *w, int *h) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return -1;
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) { fclose(fp); return -1; }
    png_infop info = png_create_info_struct(png);
    if (!info) { png_destroy_read_struct(&png, NULL, NULL); fclose(fp); return -1; }
    if (setjmp(png_jmpbuf(png))) { png_destroy_read_struct(&png, &info, NULL); fclose(fp); return -1; }
    png_init_io(png, fp);
    png_read_info(png, info);
    *w = png_get_image_width(png, info);
    *h = png_get_image_height(png, info);
    int color_type = png_get_color_type(png, info);
    if (color_type == PNG_COLOR_TYPE_PALETTE) png_set_palette_to_rgb(png);
    if (color_type == PNG_COLOR_TYPE_GRAY && png_get_bit_depth(png, info) < 8) png_set_expand_gray_1_2_4_to_8(png);
    if (png_get_valid(png, info, PNG_INFO_tRNS)) png_set_tRNS_to_alpha(png);
    if (color_type == PNG_COLOR_TYPE_RGB || color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_PALETTE) png_set_filler(png, 0xFF, PNG_FILLER_AFTER);
    if (color_type == PNG_COLOR_TYPE_GRAY || color_type == PNG_COLOR_TYPE_GRAY_ALPHA) png_set_gray_to_rgb(png);
    png_read_update_info(png, info);
    int rowbytes = png_get_rowbytes(png, info);
    *out = malloc(rowbytes * *h);
    png_bytep rows[*h];
    for (int i = 0; i < *h; i++) rows[i] = *out + i * rowbytes;
    png_read_image(png, rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);
    return rowbytes;
}

static int load_jpeg(const char *path, unsigned char **out, int *w, int *h) {
    FILE *fp = fopen(path, "rb");
    if (!fp) return -1;
    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, fp);
    jpeg_read_header(&cinfo, TRUE);
    cinfo.out_color_space = JCS_RGB;
    jpeg_start_decompress(&cinfo);
    *w = cinfo.output_width;
    *h = cinfo.output_height;
    *out = malloc(*w * *h * 4);
    unsigned char *row = malloc(*w * 3);
    for (int y = 0; y < *h; y++) {
        jpeg_read_scanlines(&cinfo, &row, 1);
        for (int x = 0; x < *w; x++) {
            (*out)[(y * *w + x) * 4 + 0] = row[x * 3 + 0];
            (*out)[(y * *w + x) * 4 + 1] = row[x * 3 + 1];
            (*out)[(y * *w + x) * 4 + 2] = row[x * 3 + 2];
            (*out)[(y * *w + x) * 4 + 3] = 0xFF;
        }
    }
    free(row);
    jpeg_destroy_decompress(&cinfo);
    fclose(fp);
    return *w * 4;
}

int main(int argc, char *argv[]) {
    if (argc != 2) { fprintf(stderr, "Usage: fb_display <image.png|image.jpg>\n"); return 1; }
    read_fb_geometry();
    unsigned char *rgba = NULL;
    int img_w = 0, img_h = 0, rowbytes = 0;
    const char *ext = strrchr(argv[1], '.');
    if (ext && (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0)) {
        if (load_jpeg(argv[1], &rgba, &img_w, &img_h) != 0) { fprintf(stderr, "Failed to load JPEG\n"); return 1; }
        rowbytes = img_w * 4;
    } else {
        if (load_png(argv[1], &rgba, &img_w, &img_h) != 0) { fprintf(stderr, "Failed to load PNG\n"); return 1; }
        rowbytes = img_w * 4;
    }
    int fd = open("/dev/fb0", O_RDWR);
    if (fd < 0) { perror("open fb0"); free(rgba); return 1; }
    void *fb = mmap(NULL, stride * fb_h, PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb == MAP_FAILED) { perror("mmap fb0"); close(fd); free(rgba); return 1; }
    memset(fb, 0, stride * fb_h);
    int copy_h = img_h < fb_h ? img_h : fb_h;
    for (int y = 0; y < copy_h; y++) {
        memcpy((char *)fb + y * stride, rgba + y * rowbytes, rowbytes < stride ? rowbytes : stride);
    }
    munmap(fb, stride * fb_h);
    close(fd);
    free(rgba);
    return 0;
}
