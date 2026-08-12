/*
 * P3.2 emulator: map QEMU virtio-tablet (host mouse on macOS cocoa) to a
 * libinput touch device via uinput — same idea as Android Emulator's
 * goldfish events_device / android_virtio_touch_event UI glue.
 *
 * Grab the tablet node so Weston/Flutter see touch-only input in touch mode.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#ifndef INPUT_PROP_DIRECT
#define INPUT_PROP_DIRECT 0x01
#endif

#ifndef EVIOCABSINFO
#define EVIOCABSINFO(abs) _IOR('E', 0x40 + (abs), struct input_absinfo)
#endif

#define SCROLL_PX 80

static int clamp(int v, int lo, int hi)
{
	if (v < lo)
		return lo;
	if (v > hi)
		return hi;
	return v;
}

/* Normalize REL_WHEEL (±1 or ±120 per notch) to signed step count. */
static int wheel_steps(int value)
{
	int sign, mag;

	if (value == 0)
		return 0;
	sign = (value > 0) ? 1 : -1;
	mag = value > 0 ? value : -value;
	if (mag >= 120)
		mag = mag / 120;
	else if (mag > 10)
		mag = (mag + 119) / 120;
	if (mag < 1)
		mag = 1;
	return sign * mag;
}

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
	struct input_event ev = { .type = type, .code = code, .value = value };
	if (write(ufd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev))
		return -1;
	return 0;
}

static int setup_uinput(int max_x, int max_y)
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
		perror("UI_SET_*BIT");
		close(ufd);
		return -1;
	}

	memset(&abs_setup, 0, sizeof(abs_setup));
	abs_setup.code = ABS_MT_POSITION_X;
	abs_setup.absinfo.minimum = 0;
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
		perror("UI_DEV_CREATE");
		close(ufd);
		return -1;
	}
	usleep(100000);
	fprintf(stderr, " → uinput %dx%d\n", max_x + 1, max_y + 1);
	return ufd;
}

static void sync_touch(int ufd, int x, int y, int down)
{
	emit(ufd, EV_ABS, ABS_MT_SLOT, 0);
	if (down) {
		emit(ufd, EV_ABS, ABS_MT_TRACKING_ID, 1);
		emit(ufd, EV_ABS, ABS_MT_POSITION_X, x);
		emit(ufd, EV_ABS, ABS_MT_POSITION_Y, y);
		emit(ufd, EV_KEY, BTN_TOUCH, 1);
	} else {
		emit(ufd, EV_ABS, ABS_MT_TRACKING_ID, -1);
		emit(ufd, EV_KEY, BTN_TOUCH, 0);
	}
	emit(ufd, EV_SYN, SYN_REPORT, 0);
}

/* Wheel → brief touch flick (Android Emulator–style list scroll). */
static void touch_flick(int ufd, int x0, int y0, int dx, int dy, int max_x, int max_y)
{
	int x1 = clamp(x0 + dx, 0, max_x);
	int y1 = clamp(y0 + dy, 0, max_y);

	sync_touch(ufd, x0, y0, 1);
	sync_touch(ufd, x1, y1, 1);
	sync_touch(ufd, x1, y1, 0);
}

int main(void)
{
	int tfd, ufd, max_x, max_y, x = 0, y = 0, down = 0;

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

	max_x = abs_max(tfd, ABS_X, 1535);
	max_y = abs_max(tfd, ABS_Y, 959);

	ufd = setup_uinput(max_x, max_y);
	if (ufd < 0)
		return 1;

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
			if (ev.code == ABS_X)
				x = ev.value;
			else if (ev.code == ABS_Y)
				y = ev.value;
			if (down)
				sync_touch(ufd, x, y, 1);
			break;
		case EV_KEY:
			if (ev.code != BTN_LEFT && ev.code != BTN_TOUCH)
				break;
			if (ev.value) {
				down = 1;
				sync_touch(ufd, x, y, 1);
			} else if (down) {
				down = 0;
				sync_touch(ufd, x, y, 0);
			}
			break;
		case EV_REL:
			/* Skip while finger is down — drag already scrolls. */
			if (down)
				break;
			if (ev.code == REL_WHEEL) {
				int steps = wheel_steps(ev.value);

				if (steps)
					/* Wheel down → content up → finger moves up (y−). */
					touch_flick(ufd, x, y, 0, -steps * SCROLL_PX,
						    max_x, max_y);
			} else if (ev.code == REL_HWHEEL) {
				int steps = wheel_steps(ev.value);

				if (steps)
					touch_flick(ufd, x, y, -steps * SCROLL_PX, 0,
						    max_x, max_y);
			}
			break;
		default:
			break;
		}
	}
	return 1;
}
