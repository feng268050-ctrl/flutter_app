#!/bin/sh
# Start/stop USB plug-ssh when USB Debug is on and OTG reports VBUS (USB=1).
set -eu

LOCK_DIR=/run/usb-plug-ssh-vbus.lock
PENDING=/run/usb-plug-ssh-vbus.pending
PREF=/var/lib/hal/usb-debug

usb_debug_on() {
	if [ ! -r "$PREF" ]; then
		return 0
	fi
	case "$(tr -d ' \n' <"$PREF")" in
	0 | off | false | host) return 1 ;;
	*) return 0 ;;
	esac
}

otg_extcon_state() {
	local state dir dev
	for state in /sys/class/extcon/extcon*/state; do
		[ -r "$state" ] || continue
		dir="$(dirname "$state")"
		dev="$(readlink -f "$dir" 2>/dev/null || true)"
		case "$dev" in
		*fe8a0000* | *usb2phy0*)
			cat "$state"
			return 0
			;;
		esac
	done
	return 1
}

otg_peripheral_vbus_up() {
	local state
	usb_debug_on || return 1
	state="$(otg_extcon_state)" || return 1
	echo "$state" | grep -qE '(^|[[:space:]])USB-HOST=1([[:space:]]|$)' && return 1
	echo "$state" | grep -qE '(^|[[:space:]])USB=1([[:space:]]|$)'
}

reconcile_vbus() {
	if otg_peripheral_vbus_up; then
		systemctl start ssh-debug-usb.service 2>/dev/null || true
	else
		systemctl stop ssh-debug-usb.service 2>/dev/null || true
	fi
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	touch "$PENDING"
	exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT HUP INT TERM

while true; do
	rm -f "$PENDING"
	sleep 1
	reconcile_vbus
	sleep 0.2
	reconcile_vbus
	[ -f "$PENDING" ] || break
done
