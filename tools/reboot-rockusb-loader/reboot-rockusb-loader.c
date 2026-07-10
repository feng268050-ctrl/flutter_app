// Reboot into Rockchip RockUSB Loader (BOOT_BL_DOWNLOAD) via RESTART2.
// Do not use busybox reboot or systemctl reboot — lws-hmi shutdown.sh uses sysrq.
#include <errno.h>
#include <linux/reboot.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

static int reboot_restart2(const char *mode)
{
	return syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
		       LINUX_REBOOT_CMD_RESTART2, mode);
}

static void usage(const char *prog)
{
	fprintf(stderr,
		"Usage: %s [loader|bootloader]\n"
		"Reboot into RockUSB Loader mode for upgrade_tool / make flash.\n",
		prog);
}

int main(int argc, char **argv)
{
	const char *mode = "loader";

	if (argc > 2) {
		usage(argv[0]);
		return 2;
	}
	if (argc == 2) {
		if (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help")) {
			usage(argv[0]);
			return 0;
		}
		mode = argv[1];
		if (strcmp(mode, "loader") && strcmp(mode, "bootloader")) {
			fprintf(stderr, "%s: unknown mode '%s'\n", argv[0], mode);
			usage(argv[0]);
			return 2;
		}
	}

	sync();
	fprintf(stderr, "%s: RESTART2 mode='%s'\n", argv[0], mode);
	fflush(stderr);

	if (reboot_restart2(mode) < 0) {
		perror("reboot");
		return 1;
	}
	return 0;
}
