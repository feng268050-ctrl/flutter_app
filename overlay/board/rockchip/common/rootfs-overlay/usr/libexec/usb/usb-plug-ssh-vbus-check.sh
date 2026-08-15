#!/bin/sh
# Start/stop USB plug-ssh when persisted OTG mode=debug and VBUS (USB=1).
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true
# shellcheck source=/dev/null
. /usr/libexec/usb/usb-otg-paths.sh

LOCK_DIR="${RUN_USB_PLUG_SSH_VBUS_LOCK:-/run/usb-plug-ssh-vbus.lock}"
PENDING="${RUN_USB_PLUG_SSH_VBUS_PENDING:-/run/usb-plug-ssh-vbus.pending}"
CONF="${VAR_HAL:-/var/lib/hal}/usb-otg.conf"

mode_is_debug() {
	if [ -r "$CONF" ]; then
		case "$(grep -E '^mode=' "$CONF" 2>/dev/null | head -n1 | cut -d= -f2- | tr -d ' \n' | tr '[:upper:]' '[:lower:]')" in
		debug | usb-debug) return 0 ;;
		*) return 1 ;;
		esac
	fi
	# Missing conf → treat as debug (same as usb-otg-mode.sh read_mode default).
	return 0
}

otg_peripheral_vbus_up() {
	local state
	mode_is_debug || return 1
	state="$(usb_otg_read_extcon_state)" || return 1
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
