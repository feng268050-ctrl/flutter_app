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

for unit in lws-hmi-debug-boot.service mediamtx.service sshd.service sshd.socket bluetooth.service; do
	disable_unit "$unit"
done

rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/debug-boot.sh"

link_unit mainserver.service
link_unit lws-hmi-performance.service
link_unit hmi.service

ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"
