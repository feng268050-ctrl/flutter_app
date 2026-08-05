#!/bin/sh
# Mirror Android UsbDeviceManager: apply kernel USB_STATE from android_work.
#
# Android listens for uevents on /devices/virtual/android_usb/* with
# USB_STATE=DISCONNECTED|CONNECTED|CONFIGURED (see UsbDeviceManager UEventObserver).
# We persist the same into /run for HAL/status-bar.
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true

STATE_FILE="${RUN_USB_GADGET_USB_STATE:-/run/usb-gadget-usb-state}"
# 0 = disconnected (Android: connected=false)
# 1 = connected or configured (Android: connected=true)

mkdir -p "$(dirname "$STATE_FILE")"

apply() {
	local s
	s="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | tr -d ' \n')"
	case "$s" in
	DISCONNECTED)
		echo 0 >"$STATE_FILE"
		;;
	CONNECTED | CONFIGURED)
		echo 1 >"$STATE_FILE"
		;;
	*)
		return 0
		;;
	esac
}

# Seed from sysfs (boot / mode switch) — same values Android reads.
seed_from_sysfs() {
	local st state
	for st in /sys/class/android_usb/*/state; do
		[ -r "$st" ] || continue
		state="$(tr -d ' \n' <"$st" 2>/dev/null || true)"
		case "$state" in
		CONFIGURED | CONNECTED)
			echo 1 >"$STATE_FILE"
			return 0
			;;
		DISCONNECTED)
			echo 0 >"$STATE_FILE"
			return 0
			;;
		esac
	done
	# No android_usb (e.g. legacy g_ether debug): leave file absent for fallback.
	rm -f "$STATE_FILE" 2>/dev/null || true
}

cmd="${1:-}"
case "$cmd" in
seed)
	seed_from_sysfs
	;;
DISCONNECTED | CONNECTED | CONFIGURED)
	apply "$cmd"
	;;
*)
	# udev may pass nothing; use ENV{USB_STATE} if exported.
	if [ -n "${USB_STATE:-}" ]; then
		apply "$USB_STATE"
	else
		seed_from_sysfs
	fi
	;;
esac
