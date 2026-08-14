#!/bin/sh
# Refresh Plan A systemd wants on staging target/ (multi-user + sysinit early HMI).
# Called from post-build.sh, lws-hmi-rootfs-postprocess.sh, and post-fakeroot.sh
# so verify-rootfs-overlay staging checks match the flash image.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"

SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
WANTS="$SYSTEMD_DIR/multi-user.target.wants"
SYSINIT_WANTS="$SYSTEMD_DIR/sysinit.target.wants"
mkdir -p "$WANTS" "$SYSINIT_WANTS"

link_boot_unit() {
	unit="$1"
	[ -f "$SYSTEMD_DIR/$unit" ] || return 0
	ln -sfn "/etc/systemd/system/$unit" "$WANTS/$unit"
}

link_boot_unit_sysinit() {
	unit="$1"
	[ -f "$SYSTEMD_DIR/$unit" ] || return 0
	ln -sfn "/etc/systemd/system/$unit" "$SYSINIT_WANTS/$unit"
}

if [ -f "$SYSTEMD_DIR/storage-init.service" ]; then
	ln -sfn "/etc/systemd/system/storage-init.service" \
		"$SYSINIT_WANTS/storage-init.service"
fi

for unit in cpu-performance.service serial-stty.service \
	pwrkey-poweroff.service ab-boot-confirm.service oem-compose.service \
	tee-supplicant.service usb-otg-role-boot.service hmi.service; do
	link_boot_unit "$unit"
done

for unit in cpu-performance.service oem-compose.service hmi.service; do
	link_boot_unit_sysinit "$unit"
done
