/*
 * fb_display - Minimal framebuffer image viewer for PS4 RetroBox
 * Displays PNG/JPEG images on /dev/fb0 with correct stride handling.
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

static void display_rgba(unsigned char *rgba, int img_w, int img_h) {
    int fd = open("/dev/fb0", O_RDWR);
    if (fd < 0) { perror("open /dev/fb0"); return; }
    void *fb = mmap(NULL, stride * fb_h, PROT_WRITE, MAP_SHARED, fd, 0);
    if (fb == MAP_FAILED) { perror("mmap fb0"); close(fd); return; }

    int off_x = (fb_w - img_w) / 2;
    int off_y = (fb_h - img_h) / 2;
    if (off_x < 0) off_x = 0;
    if (off_y < 0) off_y = 0;

    int copy_w = img_w;
    if (off_x + copy_w > fb_w) copy_w = fb_w - off_x;
    int copy_h = img_h;
    if (off_y + copy_h > fb_h) copy_h = fb_h - off_y;

    for (int y = 0; y < copy_h; y++) {
        memcpy((char *)fb + (off_y + y) * stride + off_x * 4,
               rgba + y * img_w * 4, copy_w * 4);
    }

    munmap(fb, stride * fb_h);
    close(fd);
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
    png_set_expand(png);
    png_set_filler(png, 0xFF, PNG_FILLER_AFTER);
    png_set_gray_to_rgb(png);
    png_read_update_info(png, info);
    *out = malloc(*w * *h * 4);
    png_bytep rows[*h];
    for (int i = 0; i < *h; i++) rows[i] = *out + i * *w * 4;
    png_read_image(png, rows);
    png_destroy_read_struct(&png, &info, NULL);
    fclose(fp);
    return 0;
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
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: fb_display <image.png|image.jpg>\n");
        return 1;
    }
    read_fb_geometry();
    unsigned char *rgba = NULL;
    int img_w = 0, img_h = 0;
    const char *ext = strrchr(argv[1], '.');
    if (ext && (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0)) {
        if (load_jpeg(argv[1], &rgba, &img_w, &img_h) != 0) {
            fprintf(stderr, "Failed to load JPEG: %s\n", argv[1]);
            return 1;
        }
    } else {
        if (load_png(argv[1], &rgba, &img_w, &img_h) != 0) {
            fprintf(stderr, "Failed to load PNG: %s\n", argv[1]);
            return 1;
        }
    }
    display_rgba(rgba, img_w, img_h);
    free(rgba);
    return 0;
}
