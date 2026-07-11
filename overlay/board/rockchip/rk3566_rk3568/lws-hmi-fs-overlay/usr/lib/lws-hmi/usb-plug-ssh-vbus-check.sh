#!/bin/sh
# Start/stop USB plug-ssh when Rockchip usb2phy0 (fe8a0000 OTG) extcon reports VBUS.
set -eu

otg_vbus_up() {
	local state dir dev
	for state in /sys/class/extcon/extcon*/state; do
		[ -r "$state" ] || continue
		dir="$(dirname "$state")"
		dev="$(readlink -f "$dir" 2>/dev/null || true)"
		case "$dev" in
		*fe8a0000* | *usb2phy0*)
			if grep -qE '(^|[[:space:]])USB=1([[:space:]]|$)' "$state" 2>/dev/null; then
				return 0
			fi
			;;
		esac
	done
	return 1
}

if otg_vbus_up; then
	systemctl start lws-hmi-usb-plug-ssh.service 2>/dev/null || true
else
	systemctl stop lws-hmi-usb-plug-ssh.service 2>/dev/null || true
fi
