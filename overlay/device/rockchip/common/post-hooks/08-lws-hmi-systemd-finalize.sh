#!/bin/bash -e

# Plan A B-9: Rockchip 07-log-guardian.sh runs after 06-lws-hmi-systemd.sh and
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
			echo "lws-hmi-systemd-finalize: removed ${link#$TARGET_DIR/}"
		fi
	done
}

for unit in lws-hmi-debug-boot.service lws-hmi-usb-plug-ssh.service mediamtx.service sshd.service sshd.socket \
	bluetooth.service wifibt-init.service wpa_supplicant.service network.service \
	log-guardian.service lws-hmi-boot-kpi.service usbdevice.service; do
	disable_boot_unit "$unit"
done

# Rockchip usbdevice (RK_USB_GADGET) binds the same UDC as lws-hmi USB plug-ssh ECM.
strip_rockchip_usbdevice() {
	if [ -d "$SYSTEMD_DIR" ]; then
		ln -sf /dev/null "$SYSTEMD_DIR/usbdevice.service"
		echo "lws-hmi-systemd-finalize: masked usbdevice.service"
	fi
	rm -f \
		"$TARGET_DIR/usr/bin/usbdevice" \
		"$TARGET_DIR/lib/udev/rules.d/61-usbdevice.rules" \
		"$TARGET_DIR/etc/profile.d/usbdevice.sh" \
		"$TARGET_DIR/usr/lib/systemd/system/usbdevice.service" \
		"$TARGET_DIR/lib/systemd/system/usbdevice.service"
}
strip_rockchip_usbdevice

rm -f \
	"$TARGET_DIR/etc/systemd/system/lws-hmi-boot-kpi.service" \
	"$TARGET_DIR/usr/lib/lws-hmi/boot-kpi-watch.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/configure-camera-eth0.sh" \
	"$TARGET_DIR/usr/lib/lws-hmi/enable-ssh-debug.sh"
