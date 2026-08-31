/*
 * hdmi-force.c — Forces HDMI PHY re-init by clearing and re-setting CRTC.
 * Creates dumb buffer + framebuffer, clears CRTC (PHY power-down),
 * waits 1 second, re-sets mode (PHY power-up with fresh link negotiation).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <xf86drm.h>
#include <xf86drmMode.h>
#include <drm/drm.h>
#include <drm/drm_mode.h>
#include <drm/drm_fourcc.h>

int main(void)
{
    int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("open"); return 1; }

    ioctl(fd, DRM_IOCTL_SET_MASTER, 0);

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) { fprintf(stderr, "drmModeGetResources failed\n"); close(fd); return 1; }

    for (int i = 0; i < res->count_connectors; i++) {
        drmModeConnector *conn = drmModeGetConnector(fd, res->connectors[i]);
        if (!conn) continue;
        if (conn->connector_type != DRM_MODE_CONNECTOR_HDMIA) { drmModeFreeConnector(conn); continue; }
        if (conn->connection != DRM_MODE_CONNECTED || conn->count_modes == 0) { drmModeFreeConnector(conn); continue; }

        drmModeModeInfo *mode = &conn->modes[0];
        for (int m = 0; m < conn->count_modes; m++) {
            if (conn->modes[m].type & DRM_MODE_TYPE_PREFERRED) { mode = &conn->modes[m]; break; }
        }

        uint32_t crtc_id = 0;
        if (conn->encoder_id) {
            drmModeEncoder *enc = drmModeGetEncoder(fd, conn->encoder_id);
            if (enc) { crtc_id = enc->crtc_id; drmModeFreeEncoder(enc); }
        }
        if (!crtc_id && res->count_crtcs > 0) crtc_id = res->crtcs[0];
        if (!crtc_id) { drmModeFreeConnector(conn); continue; }

        fprintf(stderr, "Connector %d CRTC %d: clearing then re-setting %s\n",
                conn->connector_id, crtc_id, mode->name);

        /* Step 1: Clear CRTC — powers down HDMI PHY */
        fprintf(stderr, "  Step 1: Clearing CRTC (PHY power down)...\n");
        drmModeSetCrtc(fd, crtc_id, 0, 0, 0, NULL, 0, NULL);
        sleep(2);

        /* Step 2: Re-set with dummy FB — powers up PHY, forces fresh link negotiation */
        fprintf(stderr, "  Step 2: Setting mode (PHY power up, link re-negotiation)...\n");

        /* Create dumb buffer */
        struct drm_mode_create_dumb creq = {0};
        creq.width = mode->hdisplay;
        creq.height = mode->vdisplay;
        creq.bpp = 32;
        if (ioctl(fd, DRM_IOCTL_MODE_CREATE_DUMB, &creq) == 0) {
            /* Create FB using dumb buffer with drmModeAddFB2 */
            uint32_t handles[4] = { creq.handle, 0, 0, 0 };
            uint32_t pitches[4] = { creq.pitch, 0, 0, 0 };
            uint32_t offsets[4] = { 0, 0, 0, 0 };
            uint32_t fb_id = 0;

            if (drmModeAddFB2(fd, mode->hdisplay, mode->vdisplay,
                              DRM_FORMAT_ARGB8888, handles, pitches, offsets, &fb_id, 0) == 0) {
                int ret = drmModeSetCrtc(fd, crtc_id, fb_id, 0, 0, &conn->connector_id, 1, mode);
                if (ret < 0)
                    fprintf(stderr, "  drmModeSetCrtc failed: %s\n", strerror(-ret));
                else
                    fprintf(stderr, "  Mode set OK! HDMI PHY re-initialized.\n");

                drmModeRmFB(fd, fb_id);
            } else {
                fprintf(stderr, "  AddFB2 failed: %s\n", strerror(errno));
            }

            struct drm_mode_destroy_dumb dreq = { .handle = creq.handle };
            ioctl(fd, DRM_IOCTL_MODE_DESTROY_DUMB, &dreq);
        } else {
            fprintf(stderr, "  CreateDumb failed: %s\n", strerror(errno));
        }

        drmModeFreeConnector(conn);
        break;
    }

    drmModeFreeResources(res);
    ioctl(fd, DRM_IOCTL_DROP_MASTER, 0);
    close(fd);
    fprintf(stderr, "Done.\n");
    return 0;
}
