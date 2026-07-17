#!/bin/sh
# Plan A: run after systemd preset-all during rootfs.ext2 fakeroot (see systemd.mk
# SYSTEMD_ROOTFS_PRE_CMD_HOOKS). Post-rootfs hooks clean BASE target/; preset-all
# re-enables units in the image copy — undo that here before mkfs.ext2.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"
WANTS="$SYSTEMD_DIR/multi-user.target.wants"

PURGE="$(dirname "$0")/purge-retired-rootfs-artifacts.sh"
if [ -f "$PURGE" ]; then
	sh "$PURGE" "$TARGET_DIR"
fi

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

for unit in input-event-daemon.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service dhcpcd.service log-guardian.service usbdevice.service ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
	disable_unit "$unit"
done

# preset-all may re-link units with [Install]; explicit disable clears all wants.
if command -v systemctl >/dev/null 2>&1; then
	for unit in input-event-daemon.service mediamtx.service sshd.service sshd.socket bluetooth.service wifibt-init.service wpa_supplicant.service network.service dhcpcd.service log-guardian.service usbdevice.service ssh-debug-lan.service wlan-wpa.service wlan-dhcp.service eth0-network.service; do
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
	"$TARGET_DIR/usr/libexec/hmi/debug-boot.sh" \
	"$TARGET_DIR/usr/libexec/hmi/stop-hmi.sh" \
	"$TARGET_DIR/usr/libexec/hmi/push-app-apply-and-reboot.sh"
rmdir \
	"$TARGET_DIR/etc/systemd/system/systemd-poweroff.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-halt.service.d" \
	"$TARGET_DIR/etc/systemd/system/systemd-reboot.service.d" \
	2>/dev/null || true

link_unit mainserver.service
link_unit cpu-performance.service
link_unit serial-stty.service
link_unit pwrkey-poweroff.service
link_unit settings-restore.service
link_unit ab-boot-confirm.service
link_unit hmi.service

ln -sf /dev/null "$SYSTEMD_DIR/systemd-network-generator.service"

SYNC_ENGINE="$(dirname "$0")/sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
ENSURE_KEYS="$TARGET_DIR/usr/libexec/hmi/ensure-sshd-hostkeys.sh"
if [ ! -f "$ENSURE_KEYS" ]; then
	ENSURE_KEYS="$LWS_HMI_ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/ensure-sshd-hostkeys.sh"
fi
if [ -f "$ENSURE_KEYS" ]; then
	sh "$ENSURE_KEYS" "$TARGET_DIR"
fi

STRIP_FSTAB="$(dirname "$0")/strip-fstab.sh"
if [ -f "$STRIP_FSTAB" ]; then
	bash "$STRIP_FSTAB" "$TARGET_DIR"
fi

sh "$(dirname "$0")/install-systemctl-wrapper.sh" "$TARGET_DIR" post-fakeroot
