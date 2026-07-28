#!/bin/sh
# Thin rootfs stub — board USB OTG policy lives on OEM (W2).
# /usr/bin/usb-otg-mode → this file (post-build symlink).
set -eu

HELPER=""
if [ -n "${USB_OTG_MODE_HELPER:-}" ] && [ -x "$USB_OTG_MODE_HELPER" ]; then
	HELPER="$USB_OTG_MODE_HELPER"
elif [ -f /run/hmi/oem.env ]; then
	# shellcheck source=/dev/null
	. /run/hmi/oem.env
	if [ -n "${USB_OTG_MODE_HELPER:-}" ] && [ -x "$USB_OTG_MODE_HELPER" ]; then
		HELPER="$USB_OTG_MODE_HELPER"
	fi
fi
if [ -z "$HELPER" ] && [ -f /run/hmi/board_profile.json ]; then
	HELPER="$(sed -n 's/.*"usb_otg_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /run/hmi/board_profile.json | head -1)"
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	if [ -f /oem/manifest.json ]; then
		board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
		cand="/oem/${board_path}/helpers/usb-otg-mode.sh"
		[ -n "$board_path" ] && [ -x "$cand" ] && HELPER="$cand"
	fi
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	if grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
		echo "usb-otg-mode: skip on emulator (no OTG)" >&2
		exit 0
	fi
	if [ -f /run/hmi/board_profile.json ] &&
		grep -q '"board_id"[[:space:]]*:[[:space:]]*"sim"' /run/hmi/board_profile.json 2>/dev/null; then
		echo "usb-otg-mode: skip on sim board (no usbOtg)" >&2
		exit 0
	fi
	echo "usb-otg-mode: OEM helper missing" >&2
	exit 1
fi
exec "$HELPER" "$@"
