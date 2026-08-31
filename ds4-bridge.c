/*
 * ds4-bridge.c — Bridges DS4 from js0 → uinput virtual joystick.
 *
 * js0 and event3 have IDENTICAL button ordering (both based on KEY bitmask
 * 0x3fff = 14 buttons BTN_SOUTH through BTN_THUMBL). BTN_C(306) and BTN_Z(309)
 * are included in BOTH. The bridge forwards js0 buttons as their exact evdev
 * codes so es_input.cfg indices remain correct.
 *
 * D-pad: js0 axes 6/7 → ABS_HAT0X/Y with sign fix for PS4 kernel inversion.
 * Reconnect: retries every 1s if js0 drops. Uinput stays alive.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <time.h>

#define JS_DEV "/dev/input/js0"
#define VIRT_NAME "PS4 DS4 Bridge Joystick"

static volatile int running = 1;

struct js_event {
    unsigned int time;
    short value;
    unsigned char type;
    unsigned char number;
};

#define JS_EVENT_BUTTON 0x01
#define JS_EVENT_AXIS   0x02
#define JS_EVENT_MASK   0x7f

/*
 * js0 button N → evdev BTN_* code.
 * js0 and event3 share the same 14-button ordering from KEY bitmask 0x3fff:
 *   0=SOUTH(Cross) 1=EAST(Circle) 2=C(extra) 3=NORTH(Triangle)
 *   4=WEST(Square) 5=Z(extra) 6=TL(L1) 7=TR(R1)
 *   8=TL2(L2dig) 9=TR2(R2dig) 10=SELECT(Share) 11=START(Options)
 *   12=MODE(PS) 13=THUMBL(L3)
 */
static const unsigned short js_to_evdev_btn[] = {
    BTN_SOUTH, BTN_EAST, BTN_C, BTN_NORTH, BTN_WEST, BTN_Z,
    BTN_TL, BTN_TR, BTN_TL2, BTN_TR2,
    BTN_SELECT, BTN_START, BTN_MODE,
    BTN_THUMBL,
};

static const unsigned short js_to_evdev_abs[] = {
    ABS_X, ABS_Y, ABS_Z, ABS_RX, ABS_RY, ABS_RZ,
    ABS_HAT0X, ABS_HAT0Y,
};

#define NUM_BUTTONS (sizeof(js_to_evdev_btn) / sizeof(js_to_evdev_btn[0]))
#define NUM_AXES    (sizeof(js_to_evdev_abs) / sizeof(js_to_evdev_abs[0]))

static void emit_event(int ufd, int type, int code, int value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type = type;
    ev.code = code;
    ev.value = value;
    write(ufd, &ev, sizeof(ev));
}

static int create_uinput_device(void)
{
    int fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
    if (fd < 0) { perror("open /dev/uinput"); return -1; }

    ioctl(fd, UI_SET_EVBIT, EV_KEY);
    for (unsigned int i = 0; i < NUM_BUTTONS; i++)
        ioctl(fd, UI_SET_KEYBIT, js_to_evdev_btn[i]);

    ioctl(fd, UI_SET_EVBIT, EV_ABS);
    for (unsigned int i = 0; i < NUM_AXES; i++)
        ioctl(fd, UI_SET_ABSBIT, js_to_evdev_abs[i]);

    for (unsigned int i = 0; i < NUM_AXES; i++) {
        struct uinput_abs_setup abs_setup;
        memset(&abs_setup, 0, sizeof(abs_setup));
        abs_setup.code = js_to_evdev_abs[i];
        abs_setup.absinfo.minimum = -32767;
        abs_setup.absinfo.maximum = 32767;
        abs_setup.absinfo.fuzz = 255;
        abs_setup.absinfo.flat = 4095;
        if (js_to_evdev_abs[i] == ABS_HAT0X || js_to_evdev_abs[i] == ABS_HAT0Y) {
            abs_setup.absinfo.minimum = -1;
            abs_setup.absinfo.maximum = 1;
            abs_setup.absinfo.fuzz = 0;
            abs_setup.absinfo.flat = 0;
        }
        ioctl(fd, UI_ABS_SETUP, &abs_setup);
    }

    struct uinput_setup usetup;
    memset(&usetup, 0, sizeof(usetup));
    strncpy(usetup.name, VIRT_NAME, UINPUT_MAX_NAME_SIZE - 1);
    usetup.id.bustype = BUS_USB;
    usetup.id.vendor  = 0x054c;
    usetup.id.product = 0x09cc;
    usetup.id.version = 0x111;
    ioctl(fd, UI_DEV_SETUP, &usetup);
    ioctl(fd, UI_DEV_CREATE);
    fprintf(stderr, "ds4-bridge: created '%s'\n", VIRT_NAME);
    return fd;
}

static int open_js(void)
{
    int fd = open(JS_DEV, O_RDONLY | O_NONBLOCK);
    if (fd < 0 && errno != ENODEV && errno != ENOENT)
        fprintf(stderr, "ds4-bridge: open %s: %s\n", JS_DEV, strerror(errno));
    return fd;
}

static void sighandler(int sig) { (void)sig; running = 0; }

int main(void)
{
    signal(SIGINT, sighandler);
    signal(SIGTERM, sighandler);

    int ufd = create_uinput_device();
    if (ufd < 0) return 1;
    emit_event(ufd, EV_SYN, SYN_REPORT, 0);

    while (running) {
        int jsfd = open_js();
        if (jsfd < 0) {
            struct timespec ts = { .tv_sec = 1, .tv_nsec = 0 };
            nanosleep(&ts, NULL);
            continue;
        }
        fprintf(stderr, "ds4-bridge: connected\n");

        struct js_event jse;
        while (running) {
            ssize_t n = read(jsfd, &jse, sizeof(jse));
            if (n < 0) {
                if (errno == EINTR) continue;
                if (errno == EAGAIN || errno == EWOULDBLOCK) {
                    struct timespec ts = { .tv_sec = 0, .tv_nsec = 100000000 };
                    nanosleep(&ts, NULL);
                    continue;
                }
                break;
            }
            if (n == 0) break;
            if (n != sizeof(jse)) continue;

            unsigned char type = jse.type & JS_EVENT_MASK;
            if (type == JS_EVENT_BUTTON && jse.number < NUM_BUTTONS) {
                emit_event(ufd, EV_KEY, js_to_evdev_btn[jse.number], jse.value ? 1 : 0);
                emit_event(ufd, EV_SYN, SYN_REPORT, 0);
            } else if (type == JS_EVENT_AXIS && jse.number < NUM_AXES) {
                short val = jse.value;
                if (js_to_evdev_abs[jse.number] == ABS_HAT0X) val = -val;
                emit_event(ufd, EV_ABS, js_to_evdev_abs[jse.number], val);
                emit_event(ufd, EV_SYN, SYN_REPORT, 0);
            }
        }
        close(jsfd);
        fprintf(stderr, "ds4-bridge: disconnected, retrying\n");
    }

    ioctl(ufd, UI_DEV_DESTROY);
    close(ufd);
    return 0;
}
