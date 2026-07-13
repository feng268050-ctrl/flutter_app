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
	local wants_dir link
	for wants_dir in "$SYSTEMD_DIR"/*.wants \
		"$TARGET_DIR/usr/lib/systemd/system"/*.wants \
		"$TARGET_DIR/lib/systemd/system"/*.wants; do
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

for unit in input-event-daemon.service lws-hmi-debug-boot.service lws-hmi-pre-poweroff.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service usbdevice.service; do
	disable_unit "$unit"
done

# preset-all may re-link units with [Install]; explicit disable clears all wants.
if command -v systemctl >/dev/null 2>&1; then
	for unit in input-event-daemon.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service log-guardian.service usbdevice.service; do
		systemctl --root="$TARGET_DIR" disable "$unit" >/dev/null 2>&1 || true
	done
	systemctl --root="$TARGET_DIR" mask usbdevice.service >/dev/null 2>&1 || true
fi

ln -sf /dev/null "$SYSTEMD_DIR/usbdevice.service"
rm -f \
	"$TARGET_DIR/usr/bin/usbdevice" \
	"$TARGET_DIR/lib/udev/rules.d/61-usbdevice.rules" \
	"$TARGET_DIR/etc/profile.d/usbdevice.sh" \
	"$TARGET_DIR/usr/lib/systemd/system/usbdevice.service" \
	"$TARGET_DIR/lib/systemd/system/usbdevice.service"

rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-debug-boot.service" \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-pre-poweroff.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/stop-hmi.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/push-app-apply-and-reboot.sh" \
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
link_unit lws-hmi-serial-stty.service
link_unit lws-hmi-pwrkey-poweroff.service
link_unit hmi.service

ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"

SYNC_ENGINE="$(dirname "$0")/lws-hmi-sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

# RockUSB Loader reboot (RESTART2 loader) — see tools/reboot-rockusb-loader/
LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
BUILD_LOADER="$LWS_HMI_ROOT/scripts/build-reboot-rockusb-loader.sh"
if [ -f "$BUILD_LOADER" ]; then
	bash "$BUILD_LOADER" "$TARGET_DIR"
fi

ENSURE_KEYS="$TARGET_DIR/usr/lib/lws-hmi/ensure-sshd-hostkeys.sh"
if [ ! -f "$ENSURE_KEYS" ]; then
	ENSURE_KEYS="$LWS_HMI_ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi/ensure-sshd-hostkeys.sh"
fi
if [ -f "$ENSURE_KEYS" ]; then
	sh "$ENSURE_KEYS" "$TARGET_DIR"
fi

STRIP_FSTAB="$(dirname "$0")/lws-hmi-strip-fstab.sh"
if [ -f "$STRIP_FSTAB" ]; then
	bash "$STRIP_FSTAB" "$TARGET_DIR"
fi
