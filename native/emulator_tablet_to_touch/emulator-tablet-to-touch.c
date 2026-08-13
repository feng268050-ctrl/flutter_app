/*
 * P3.2 emulator: map QEMU virtio-tablet (host mouse on macOS cocoa) to:
 *   1) uinput touch  — BTN_LEFT / ABS → touch (Android Emulator–like)
 *   2) uinput wheel  — REL_WHEEL passthrough (smooth scroll; not touch-flick)
 *
 * Grab the tablet so Weston does not also see the raw pointer.
 * Wheel→touch flick was laggy and felt like taps; real REL_WHEEL + Weston
 * natural-scroll matches macOS host scrolling.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#ifndef INPUT_PROP_DIRECT
#define INPUT_PROP_DIRECT 0x01
#endif
#ifndef INPUT_PROP_POINTER
#define INPUT_PROP_POINTER 0x00
#endif

#ifndef EVIOCABSINFO
#define EVIOCABSINFO(abs) _IOR('E', 0x40 + (abs), struct input_absinfo)
#endif

#ifndef REL_WHEEL_HI_RES
#define REL_WHEEL_HI_RES 0x0b
#endif
#ifndef REL_HWHEEL_HI_RES
#define REL_HWHEEL_HI_RES 0x0c
#endif

static int g_tracking = 1;

static int abs_max(int fd, int code, int fallback)
{
	struct input_absinfo abs = {0};

	if (ioctl(fd, EVIOCABSINFO(code), &abs) == 0 && abs.maximum > 0)
		return abs.maximum;
	return fallback;
}

static int open_tablet(void)
{
	char path[64];
	char name[256];
	int i, fd;

	for (i = 0; i < 64; i++) {
		snprintf(path, sizeof(path), "/sys/class/input/event%d/device/name", i);
		FILE *f = fopen(path, "r");
		if (!f)
			continue;
		if (!fgets(name, sizeof(name), f)) {
			fclose(f);
			continue;
		}
		fclose(f);
		name[strcspn(name, "\r\n")] = '\0';
		if (strstr(name, "QEMU") == NULL && strstr(name, "Virtio") == NULL)
			continue;
		if (strstr(name, "Tablet") == NULL && strstr(name, "tablet") == NULL)
			continue;

		snprintf(path, sizeof(path), "/dev/input/event%d", i);
		fd = open(path, O_RDONLY | O_NONBLOCK);
		if (fd >= 0) {
			fprintf(stderr, "emulator-tablet-to-touch: source %s (%s)\n",
				path, name);
			return fd;
		}
	}
	return -1;
}

static int emit(int ufd, int type, int code, int value)
{
	struct input_event ev;

	memset(&ev, 0, sizeof(ev));
	ev.type = type;
	ev.code = code;
	ev.value = value;
	if (write(ufd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev))
		return -1;
	return 0;
}

static int setup_touch_uinput(int max_x, int max_y)
{
	struct uinput_setup us = { .name = "LWS Emulator Touch" };
	struct uinput_abs_setup abs_setup;
	int ufd, rc;

	ufd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (ufd < 0) {
		perror("open /dev/uinput");
		return -1;
	}

	rc = ioctl(ufd, UI_SET_EVBIT, EV_KEY);
	rc |= ioctl(ufd, UI_SET_EVBIT, EV_ABS);
	rc |= ioctl(ufd, UI_SET_EVBIT, EV_SYN);
	rc |= ioctl(ufd, UI_SET_KEYBIT, BTN_TOUCH);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_MT_SLOT);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_MT_TRACKING_ID);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_MT_POSITION_X);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_MT_POSITION_Y);
	rc |= ioctl(ufd, UI_SET_PROPBIT, INPUT_PROP_DIRECT);
	if (rc) {
		perror("touch UI_SET_*");
		close(ufd);
		return -1;
	}

	memset(&abs_setup, 0, sizeof(abs_setup));
	abs_setup.code = ABS_MT_POSITION_X;
	abs_setup.absinfo.maximum = max_x;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);
	abs_setup.code = ABS_MT_POSITION_Y;
	abs_setup.absinfo.maximum = max_y;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);
	abs_setup.code = ABS_MT_SLOT;
	abs_setup.absinfo.maximum = 9;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);
	abs_setup.code = ABS_MT_TRACKING_ID;
	abs_setup.absinfo.minimum = -1;
	abs_setup.absinfo.maximum = 65535;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);

	us.id.bustype = BUS_VIRTUAL;
	us.id.vendor = 0x27;
	us.id.product = 0x03;
	if (ioctl(ufd, UI_DEV_SETUP, &us) || ioctl(ufd, UI_DEV_CREATE)) {
		perror("touch UI_DEV_CREATE");
		close(ufd);
		return -1;
	}
	return ufd;
}

/*
 * Pointer that only exists so wheel events have a seat position + REL_WHEEL.
 * cursor-size=0 in weston keeps it invisible in touch mode.
 */
static int setup_wheel_uinput(int max_x, int max_y)
{
	struct uinput_setup us = { .name = "LWS Emulator Wheel" };
	struct uinput_abs_setup abs_setup;
	int ufd, rc;

	ufd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (ufd < 0) {
		perror("open /dev/uinput (wheel)");
		return -1;
	}

	rc = ioctl(ufd, UI_SET_EVBIT, EV_KEY);
	rc |= ioctl(ufd, UI_SET_EVBIT, EV_ABS);
	rc |= ioctl(ufd, UI_SET_EVBIT, EV_REL);
	rc |= ioctl(ufd, UI_SET_EVBIT, EV_SYN);
	rc |= ioctl(ufd, UI_SET_KEYBIT, BTN_LEFT);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_X);
	rc |= ioctl(ufd, UI_SET_ABSBIT, ABS_Y);
	rc |= ioctl(ufd, UI_SET_RELBIT, REL_WHEEL);
	rc |= ioctl(ufd, UI_SET_RELBIT, REL_HWHEEL);
	rc |= ioctl(ufd, UI_SET_RELBIT, REL_WHEEL_HI_RES);
	rc |= ioctl(ufd, UI_SET_RELBIT, REL_HWHEEL_HI_RES);
	rc |= ioctl(ufd, UI_SET_PROPBIT, INPUT_PROP_POINTER);
	if (rc) {
		perror("wheel UI_SET_*");
		close(ufd);
		return -1;
	}

	memset(&abs_setup, 0, sizeof(abs_setup));
	abs_setup.code = ABS_X;
	abs_setup.absinfo.maximum = max_x;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);
	abs_setup.code = ABS_Y;
	abs_setup.absinfo.maximum = max_y;
	ioctl(ufd, UI_ABS_SETUP, &abs_setup);

	us.id.bustype = BUS_VIRTUAL;
	us.id.vendor = 0x27;
	us.id.product = 0x04;
	if (ioctl(ufd, UI_DEV_SETUP, &us) || ioctl(ufd, UI_DEV_CREATE)) {
		perror("wheel UI_DEV_CREATE");
		close(ufd);
		return -1;
	}
	return ufd;
}

static void touch_down(int ufd, int x, int y)
{
	emit(ufd, EV_ABS, ABS_MT_SLOT, 0);
	emit(ufd, EV_ABS, ABS_MT_TRACKING_ID, g_tracking);
	emit(ufd, EV_ABS, ABS_MT_POSITION_X, x);
	emit(ufd, EV_ABS, ABS_MT_POSITION_Y, y);
	emit(ufd, EV_KEY, BTN_TOUCH, 1);
	emit(ufd, EV_SYN, SYN_REPORT, 0);
}

static void touch_move(int ufd, int x, int y)
{
	emit(ufd, EV_ABS, ABS_MT_SLOT, 0);
	emit(ufd, EV_ABS, ABS_MT_POSITION_X, x);
	emit(ufd, EV_ABS, ABS_MT_POSITION_Y, y);
	emit(ufd, EV_SYN, SYN_REPORT, 0);
}

static void touch_up(int ufd)
{
	emit(ufd, EV_ABS, ABS_MT_SLOT, 0);
	emit(ufd, EV_ABS, ABS_MT_TRACKING_ID, -1);
	emit(ufd, EV_KEY, BTN_TOUCH, 0);
	emit(ufd, EV_SYN, SYN_REPORT, 0);
	g_tracking = (g_tracking % 60000) + 1;
}

/* Place seat pointer, then emit wheel — no sleeps, no touch gesture. */
static void emit_wheel(int wfd, int x, int y, int code, int value)
{
	if (value == 0)
		return;
	emit(wfd, EV_ABS, ABS_X, x);
	emit(wfd, EV_ABS, ABS_Y, y);
	emit(wfd, EV_REL, code, value);
	emit(wfd, EV_SYN, SYN_REPORT, 0);
}

int main(void)
{
	int tfd, touch_fd, wheel_fd;
	int max_x, max_y, x = 0, y = 0, down = 0, dirty = 0;
	int pending_wheel = 0, pending_hwheel = 0;
	int pending_wheel_hi = 0, pending_hwheel_hi = 0;

	if (access("/proc/cmdline", R_OK) == 0) {
		FILE *f = fopen("/proc/cmdline", "r");
		char cmd[512] = {0};
		if (f) {
			fread(cmd, 1, sizeof(cmd) - 1, f);
			fclose(f);
			if (strstr(cmd, "lws.emulator.input=tablet"))
				return 0;
		}
	}

	tfd = open_tablet();
	if (tfd < 0) {
		fprintf(stderr, "emulator-tablet-to-touch: no virtio tablet\n");
		return 1;
	}

	max_x = abs_max(tfd, ABS_X, 32767);
	max_y = abs_max(tfd, ABS_Y, 32767);

	touch_fd = setup_touch_uinput(max_x, max_y);
	if (touch_fd < 0)
		return 1;
	wheel_fd = setup_wheel_uinput(max_x, max_y);
	if (wheel_fd < 0)
		return 1;

	usleep(100000);
	fprintf(stderr, " → touch+wheel uinput %dx%d\n", max_x + 1, max_y + 1);

	if (ioctl(tfd, EVIOCGRAB, (void *)1)) {
		perror("EVIOCGRAB tablet");
		return 1;
	}

	for (;;) {
		struct input_event ev;
		ssize_t n = read(tfd, &ev, sizeof(ev));

		if (n != (ssize_t)sizeof(ev)) {
			if (errno == EAGAIN) {
				usleep(10000);
				continue;
			}
			break;
		}
		switch (ev.type) {
		case EV_ABS:
			if (ev.code == ABS_X) {
				x = ev.value;
				dirty = 1;
			} else if (ev.code == ABS_Y) {
				y = ev.value;
				dirty = 1;
			}
			break;
		case EV_KEY:
			if (ev.code == BTN_LEFT || ev.code == BTN_TOUCH) {
				if (ev.value) {
					down = 1;
					dirty = 0;
					touch_down(touch_fd, x, y);
				} else if (down) {
					down = 0;
					dirty = 0;
					touch_up(touch_fd);
				}
				break;
			}
			if (ev.value && !down) {
				if (ev.code == BTN_GEAR_UP)
					pending_wheel += 1;
				else if (ev.code == BTN_GEAR_DOWN)
					pending_wheel -= 1;
			}
			break;
		case EV_REL:
			if (down)
				break;
			if (ev.code == REL_WHEEL)
				pending_wheel += ev.value;
			else if (ev.code == REL_HWHEEL)
				pending_hwheel += ev.value;
			else if (ev.code == REL_WHEEL_HI_RES)
				pending_wheel_hi += ev.value;
			else if (ev.code == REL_HWHEEL_HI_RES)
				pending_hwheel_hi += ev.value;
			break;
		case EV_SYN:
			if (ev.code != SYN_REPORT)
				break;
			if (down && dirty) {
				touch_move(touch_fd, x, y);
				dirty = 0;
			}
			if (!down) {
				/*
				 * Passthrough. macOS/host already applied the user's scroll
				 * direction (natural or not); do not invert here and keep
				 * guest weston natural-scroll=false to avoid double flip.
				 */
				if (pending_wheel_hi) {
					emit_wheel(wheel_fd, x, y, REL_WHEEL_HI_RES,
						   pending_wheel_hi);
					pending_wheel_hi = 0;
					pending_wheel = 0;
				} else if (pending_wheel) {
					emit_wheel(wheel_fd, x, y, REL_WHEEL,
						   pending_wheel);
					pending_wheel = 0;
				}
				if (pending_hwheel_hi) {
					emit_wheel(wheel_fd, x, y, REL_HWHEEL_HI_RES,
						   pending_hwheel_hi);
					pending_hwheel_hi = 0;
					pending_hwheel = 0;
				} else if (pending_hwheel) {
					emit_wheel(wheel_fd, x, y, REL_HWHEEL,
						   pending_hwheel);
					pending_hwheel = 0;
				}
			}
			break;
		default:
			break;
		}
	}
	return 1;
}
