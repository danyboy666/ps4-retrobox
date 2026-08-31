/*
 * hdmi-recover.c — Full HDMI recovery via DRM atomic property cycling.
 * 1. Grabs DRM master
 * 2. Sets DPMS Off (forces PHY power-down)
 * 3. Waits 3 seconds for TV to detect signal loss
 * 4. Sets DPMS On (forces PHY power-up + link re-negotiation)
 * 5. Re-sets 1920x1080 mode
 * 6. Drops DRM master
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

static int set_connector_property(int fd, uint32_t connector_id,
                                   const char *prop_name, uint64_t value)
{
    drmModeObjectProperties *props = drmModeObjectGetProperties(fd, connector_id, DRM_MODE_OBJECT_CONNECTOR);
    if (!props) return -1;

    for (uint32_t i = 0; i < props->count_props; i++) {
        drmModePropertyRes *prop = drmModeGetProperty(fd, props->props[i]);
        if (prop && strcmp(prop->name, prop_name) == 0) {
            int ret = drmModeObjectSetProperty(fd, connector_id,
                                          DRM_MODE_OBJECT_CONNECTOR,
                                          props->props[i], value);
            drmModeFreeProperty(prop);
            drmModeFreeObjectProperties(props);
            return ret;
        }
        if (prop) drmModeFreeProperty(prop);
    }
    drmModeFreeObjectProperties(props);
    return -1;
}

int main(void)
{
    int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("open"); return 1; }

    fprintf(stderr, "Acquiring DRM master...\n");
    if (ioctl(fd, DRM_IOCTL_SET_MASTER, 0) < 0) {
        fprintf(stderr, "DRM_IOCTL_SET_MASTER: %s (continuing anyway)\n", strerror(errno));
    }

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

        fprintf(stderr, "Connector %d CRTC %d\n", conn->connector_id, crtc_id);

        /* Step 1: Clear CRTC (stops scanout) */
        fprintf(stderr, "  Step 1: Clear CRTC...\n");
        drmModeSetCrtc(fd, crtc_id, 0, 0, 0, NULL, 0, NULL);

        /* Step 2: Set DPMS Off (powers down HDMI PHY) */
        fprintf(stderr, "  Step 2: DPMS Off...\n");
        set_connector_property(fd, conn->connector_id, "DPMS", 3); /* Off=3 */

        /* Step 3: Wait for TV to detect signal loss */
        fprintf(stderr, "  Step 3: Waiting 2 seconds for TV to detect signal loss...\n");
        sleep(2);

        /* Step 4: Set DPMS On (powers up HDMI PHY, forces link re-negotiation) */
        fprintf(stderr, "  Step 4: DPMS On...\n");
        set_connector_property(fd, conn->connector_id, "DPMS", 0); /* On=0 */
        sleep(2);

        /* Step 5: Re-set mode (ensures proper output) */
        fprintf(stderr, "  Step 5: Setting mode %s...\n", mode->name);
        drmModeSetCrtc(fd, crtc_id, 0, 0, 0, &conn->connector_id, 1, mode);

        fprintf(stderr, "  Done. HDMI should re-sync.\n");
        drmModeFreeConnector(conn);
        break;
    }

    drmModeFreeResources(res);
    ioctl(fd, DRM_IOCTL_DROP_MASTER, 0);
    close(fd);
    return 0;
}
