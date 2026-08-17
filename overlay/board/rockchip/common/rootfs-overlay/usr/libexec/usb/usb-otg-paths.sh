#!/bin/sh
# Shared USB OTG phy / extcon discovery (ynh960 fe8a0000, ek3562 ff740000, …).
# Sourced by plug-ssh vbus/diag and OEM usb-otg-mode helpers.
#
# Prefer (in order):
#   1. PHY_OTG_MODE env
#   2. board_profile helpers.otg_mode_sysfs (/run/hmi/board_profile.json)
#   3. first platform *.usb2-phy/otg_mode
#
# Extcon: prefer the phy that owns otg_mode; else any extcon under *.usb2-phy
# whose state carries USB= / USB-HOST= lines.

USB_OTG_PATHS_LOADED=1

usb_otg_profile_phy_mode() {
	local p
	[ -r /run/hmi/board_profile.json ] || return 1
	p="$(sed -n 's/.*"otg_mode_sysfs"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
		/run/hmi/board_profile.json | head -n1)"
	[ -n "$p" ] || return 1
	printf '%s\n' "$p"
}

usb_otg_discover_phy_mode() {
	local p
	for p in /sys/devices/platform/*.usb2-phy/otg_mode \
		/sys/devices/platform/*/*/otg_mode; do
		[ -e "$p" ] || continue
		case "$p" in
		*.usb2-phy/otg_mode | */usb2-phy/otg_mode)
			printf '%s\n' "$p"
			return 0
			;;
		esac
	done
	# Last resort: any platform otg_mode (Rockchip usb2-phy).
	for p in /sys/devices/platform/*/otg_mode; do
		[ -e "$p" ] || continue
		printf '%s\n' "$p"
		return 0
	done
	return 1
}

# Print absolute otg_mode sysfs path (may not exist yet during early boot).
usb_otg_phy_mode_path() {
	if [ -n "${PHY_OTG_MODE:-}" ]; then
		printf '%s\n' "$PHY_OTG_MODE"
		return 0
	fi
	if usb_otg_profile_phy_mode; then
		return 0
	fi
	usb_otg_discover_phy_mode
}

# Print OTG phy extcon state text (USB= / USB-HOST= …). Returns 1 if missing.
usb_otg_read_extcon_state() {
	local state dir dev phy want=""
	phy="$(usb_otg_phy_mode_path 2>/dev/null || true)"
	if [ -n "$phy" ]; then
		# /sys/devices/platform/ff740000.usb2-phy/otg_mode → …/ff740000.usb2-phy
		want="$(dirname "$phy")"
	fi
	for state in /sys/class/extcon/extcon*/state; do
		[ -r "$state" ] || continue
		dir="$(dirname "$state")"
		dev="$(readlink -f "$dir" 2>/dev/null || true)"
		[ -n "$dev" ] || continue
		if [ -n "$want" ]; then
			case "$dev" in
			"$want" | "$want"/*)
				cat "$state"
				return 0
				;;
			esac
		fi
	done
	# Fallback: any usb2-phy extcon that looks like OTG (has USB= line).
	for state in /sys/class/extcon/extcon*/state; do
		[ -r "$state" ] || continue
		dir="$(dirname "$state")"
		dev="$(readlink -f "$dir" 2>/dev/null || true)"
		case "$dev" in
		*.usb2-phy | *.usb2-phy/* | *usb2phy* | *usb2phy0*)
			if grep -qE '(^|[[:space:]])USB=' "$state" 2>/dev/null; then
				cat "$state"
				return 0
			fi
			;;
		esac
	done
	return 1
}
