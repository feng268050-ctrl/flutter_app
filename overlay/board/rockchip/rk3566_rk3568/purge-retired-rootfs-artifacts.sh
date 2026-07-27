#!/bin/sh
# Remove pre-rename rootfs artifacts that Buildroot incremental target/ keeps
# even after overlay rsync --delete (units/profile drop-ins under etc/systemd).
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"

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

# Renamed functional units (fix-hmi-system-naming).
for unit in \
	lws-hmi-ab-boot-confirm.service \
	lws-hmi-eth0.service \
	lws-hmi-performance.service \
	lws-hmi-serial-stty.service \
	lws-hmi-pwrkey-poweroff.service \
	lws-hmi-usb-otg-role.service \
	lws-hmi-usb-otg-role-boot.service \
	lws-hmi-wpa.service \
	lws-hmi-wlan0-dhcp.service \
	lws-hmi-lan-ssh.service \
	lws-hmi-settings-restore.service \
	lws-hmi-usb-plug-ssh.service \
	lws-hmi-debug-boot.service \
	lws-hmi-pre-poweroff.service \
	lws-hmi-boot-kpi.service; do
	disable_unit "$unit"
done

rm -f \
	"$SYSTEMD_DIR/lws-hmi-ab-boot-confirm.service" \
	"$SYSTEMD_DIR/lws-hmi-eth0.service" \
	"$SYSTEMD_DIR/lws-hmi-performance.service" \
	"$SYSTEMD_DIR/lws-hmi-serial-stty.service" \
	"$SYSTEMD_DIR/lws-hmi-pwrkey-poweroff.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-otg-role.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-otg-role-boot.service" \
	"$SYSTEMD_DIR/lws-hmi-wpa.service" \
	"$SYSTEMD_DIR/lws-hmi-wlan0-dhcp.service" \
	"$SYSTEMD_DIR/lws-hmi-lan-ssh.service" \
	"$SYSTEMD_DIR/lws-hmi-settings-restore.service" \
	"$SYSTEMD_DIR/lws-hmi-usb-plug-ssh.service" \
	"$SYSTEMD_DIR/lws-hmi-debug-boot.service" \
	"$SYSTEMD_DIR/lws-hmi-pre-poweroff.service" \
	"$SYSTEMD_DIR/lws-hmi-boot-kpi.service" \
	"$TARGET_DIR/etc/profile.d/lws-hmi-serial-stty.sh" \
	"$TARGET_DIR/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf" \
	"$SYSTEMD_DIR/systemd-poweroff.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$SYSTEMD_DIR/systemd-halt.service.d/50-lws-hmi-pre-poweroff.conf" \
	"$SYSTEMD_DIR/systemd-reboot.service.d/50-lws-hmi-pre-poweroff.conf"

rmdir \
	"$SYSTEMD_DIR/systemd-poweroff.service.d" \
	"$SYSTEMD_DIR/systemd-halt.service.d" \
	"$SYSTEMD_DIR/systemd-reboot.service.d" \
	2>/dev/null || true

# Renamed etc drop-ins / presets (Buildroot incremental keeps old basenames).
rm -rf "$TARGET_DIR/etc/lws-hmi"
rm -f \
	"$TARGET_DIR/etc/issue.d/00-lws-hmi-terminal-resize.issue" \
	"$TARGET_DIR/etc/systemd/network/10-lws-hmi-gmac.link" \
	"$TARGET_DIR/etc/systemd/system/bluetooth.service.d/lws-hmi.conf" \
	"$TARGET_DIR/etc/systemd/journald.conf.d/00-lws-hmi-volatile.conf" \
	"$TARGET_DIR/etc/systemd/system-preset/99-lws-hmi.preset" \
	"$TARGET_DIR/etc/ssh/sshd_config.d/50-lws-hmi-ssh-auth.conf" \
	"$TARGET_DIR/etc/udev/rules.d/99-lws-hmi-usb-plug-ssh.rules"

rm -rf "$TARGET_DIR/usr/lib/lws-hmi" "$TARGET_DIR/var/lib/lws-hmi"

# W2: no rootfs OEM migration fallback (compose fails hard without /oem).
# Buildroot incremental target/ keeps this tree after overlay rsync --delete.
rm -rf "$TARGET_DIR/usr/share/hmi/oem-fallback"

# In-HAL HOGP/evdev heal (retired board service + helpers).
disable_unit "bt-hid-heal.service"
rm -f \
	"$SYSTEMD_DIR/bt-hid-heal.service" \
	"$TARGET_DIR/usr/lib/systemd/system/bt-hid-heal.service" \
	"$TARGET_DIR/usr/libexec/bluetooth/bt-hid-heal.sh" \
	"$TARGET_DIR/usr/libexec/bluetooth/bt-hid-heal-loop.sh"
rm -rf "$TARGET_DIR/run/bt-hid" "$TARGET_DIR/var/run/bt-hid"
