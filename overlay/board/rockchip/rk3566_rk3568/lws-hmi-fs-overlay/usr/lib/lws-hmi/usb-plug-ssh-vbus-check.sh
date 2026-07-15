#!/bin/sh
# Start/stop USB plug-ssh when Rockchip usb2phy0 (fe8a0000 OTG) extcon reports VBUS.
set -eu

LOCK_DIR=/run/lws-hmi-usb-plug-ssh-vbus.lock
PENDING=/run/lws-hmi-usb-plug-ssh-vbus.pending

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

reconcile_vbus() {
	if otg_vbus_up; then
		systemctl start lws-hmi-usb-plug-ssh.service 2>/dev/null || true
	else
		systemctl stop lws-hmi-usb-plug-ssh.service 2>/dev/null || true
	fi
}

# extcon emits clustered add/change events while the PHY settles. One worker
# debounces; concurrent events set PENDING so a remplug during sleep is not lost.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	touch "$PENDING"
	exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT HUP INT TERM

while true; do
	rm -f "$PENDING"
	sleep 1
	reconcile_vbus
	# Catch a final edge that arrived while systemd was starting/stopping.
	sleep 0.2
	reconcile_vbus
	[ -f "$PENDING" ] || break
done
