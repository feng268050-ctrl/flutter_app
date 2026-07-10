#!/bin/sh
# Plan A: run after systemd preset-all during rootfs.ext2 fakeroot (see systemd.mk
# SYSTEMD_ROOTFS_PRE_CMD_HOOKS). Post-rootfs hooks clean BASE target/; preset-all
# re-enables units in the image copy — undo that here before mkfs.ext2.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
WANTS="$SYSTEMD_DIR/multi-user.target.wants"

disable_unit() {
	unit="$1"
	for wants_dir in "$SYSTEMD_DIR"/*.wants; do
		[ -d "$wants_dir" ] || continue
		link="$wants_dir/$unit"
		if [ -e "$link" ] || [ -L "$link" ]; then
			rm -f "$link"
		fi
	done
}

link_unit() {
	unit="$1"
	[ -f "$SYSTEMD_DIR/$unit" ] || return 0
	mkdir -p "$WANTS"
	ln -sf "/etc/systemd/system/$unit" "$WANTS/$unit"
}

for unit in lws-hmi-debug-boot.service lws-hmi-pre-poweroff.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service; do
	disable_unit "$unit"
done

rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-pre-poweroff.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/stop-hmi.sh" \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d/50-lws-hmi-pre-poweroff.conf"
rmdir \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d" \
	2>/dev/null || true

link_unit mainserver.service
link_unit lws-hmi-performance.service
link_unit lws-hmi-pwrkey-poweroff.service
link_unit hmi.service

ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"
