#!/bin/bash -e

# Plan A B-9: Rockchip 07-log-guardian.sh runs after 06-systemd.sh and
# re-enables log-guardian in sysinit.target.wants. Undo that here (last hook).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

SYSTEMD_DIR="$TARGET_DIR/etc/systemd/system"

disable_boot_unit() {
	local unit="$1"
	local wants_dir link
	for wants_dir in "$SYSTEMD_DIR"/*.wants \
		"$TARGET_DIR/usr/lib/systemd/system"/*.wants \
		"$TARGET_DIR/lib/systemd/system"/*.wants; do
		[ -d "$wants_dir" ] || continue
		link="$wants_dir/$unit"
		if [ -e "$link" ] || [ -L "$link" ]; then
			rm -f "$link"
			echo "post-systemd-finalize: removed ${link#$TARGET_DIR/}"
		fi
	done
}

for unit in lws-hmi-debug-boot.service ssh-debug-usb.service sshd.service sshd.socket \
	ssh-debug-lan.service bluetooth.service wifibt-init.service wpa_supplicant.service network.service dhcpcd.service \
	log-guardian.service lws-hmi-boot-kpi.service usbdevice.service \
	lws-hmi-ab-boot-confirm.service lws-hmi-performance.service lws-hmi-pwrkey-poweroff.service \
	lws-hmi-serial-stty.service lws-hmi-settings-restore.service lws-hmi-usb-otg-role-boot.service; do
	disable_boot_unit "$unit"
done

# Rockchip usbdevice (RK_USB_GADGET) binds the same UDC as lws-hmi USB plug-ssh ECM.
strip_rockchip_usbdevice() {
	if [ -d "$SYSTEMD_DIR" ]; then
		ln -sf /dev/null "$SYSTEMD_DIR/usbdevice.service"
		echo "post-systemd-finalize: masked usbdevice.service"
	fi
	rm -f \
		"$TARGET_DIR/usr/bin/usbdevice" \
		"$TARGET_DIR/lib/udev/rules.d/61-usbdevice.rules" \
		"$TARGET_DIR/etc/profile.d/usbdevice.sh" \
		"$TARGET_DIR/usr/lib/systemd/system/usbdevice.service" \
		"$TARGET_DIR/lib/systemd/system/usbdevice.service"
}
strip_rockchip_usbdevice

# D11: purge leftover dhcpcd (Buildroot does not always remove disabled pkgs).
rm -f \
	"$TARGET_DIR/usr/sbin/dhcpcd" \
	"$TARGET_DIR/sbin/dhcpcd" \
	"$TARGET_DIR/etc/dhcpcd.conf" \
	"$TARGET_DIR/usr/lib/systemd/system/dhcpcd.service" \
	"$TARGET_DIR/lib/systemd/system/dhcpcd.service" \
	"$TARGET_DIR/etc/systemd/system/dhcpcd.service"
rm -rf \
	"$TARGET_DIR/usr/share/dhcpcd" \
	"$TARGET_DIR/var/db/dhcpcd" \
	"$TARGET_DIR/etc/systemd/system/dhcpcd.service.d" \
	2>/dev/null || true
echo "post-systemd-finalize: purged dhcpcd (networkd-only L3)"

rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-boot-kpi.service" \
	"$TARGET_DIR/usr/libexec/hmi/boot-kpi-watch.sh" \
	"$TARGET_DIR/usr/libexec/hmi/configure-camera-eth0.sh" \
	"$TARGET_DIR/etc/ssh/sshd_config.d/50-lws-hmi-usb-plug-ssh.conf"
