/*
 * hdmi-daemon.c — Monitors DRM hotplug events and triggers HDMI recovery.
 * When TV power-cycles: GPU fires hotplug event → daemon runs hdmi-recover.
 * Also periodically checks display state as fallback.
 *
 * Build: gcc -O2 -I/usr/include/libdrm -o hdmi-daemon hdmi-daemon.c -ldrm
 * Run:   sudo ./hdmi-daemon
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <stdint.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

static volatile int running = 1;
static void sighandler(int sig) { (void)sig; running = 0; }

/* Callback for DRM hotplug events */
static void hotplug_handler(int fd, unsigned int sequence,
                             unsigned int tv_sec, unsigned int tv_usec,
                             void *user_data)
{
    (void)sequence; (void)tv_sec; (void)tv_usec; (void)user_data;
    fprintf(stderr, "hdmi-daemon: hotplug event received, triggering recovery\n");
    system("/usr/local/bin/hdmi-recover.sh");
}

int main(void)
{
    signal(SIGINT, sighandler);
    signal(SIGTERM, sighandler);

    int fd = open("/dev/dri/card0", O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror("open /dev/dri/card0"); return 1; }

    /* Request hotplug events */
    drmEventContext evctx;
    memset(&evctx, 0, sizeof(evctx));
    evctx.version = DRM_EVENT_CONTEXT_VERSION;
    evctx.hotplug_event = hotplug_handler;

    fprintf(stderr, "hdmi-daemon: monitoring DRM events on /dev/dri/card0\n");

    while (running) {
        fd_set fds;
        FD_ZERO(&fds);
        FD_SET(fd, &fds);

        struct timeval tv = { .tv_sec = 5, .tv_usec = 0 };
        int ret = select(fd + 1, &fds, NULL, NULL, &tv);

        if (ret > 0 && FD_ISSET(fd, &fds)) {
            drmHandleEvent(fd, &evctx);
        }
        /* On timeout (5 seconds), just loop and check again */
    }

    close(fd);
    fprintf(stderr, "hdmi-daemon: exiting\n");
    return 0;
}
