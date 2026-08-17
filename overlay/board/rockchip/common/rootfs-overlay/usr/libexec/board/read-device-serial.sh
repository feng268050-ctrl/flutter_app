#!/bin/sh
# Stable per-board serial for USB gadget iSerial and host tooling.
# Default: product SN from Vendor Storage, then chip ID (SoC / DT / machine-id).
# --chip-id: chip ID only (skip Vendor Storage).
set -eu

CHIP_ONLY=0
case "${1:-}" in
--chip-id | --chip)
	CHIP_ONLY=1
	;;
esac

read_vendor_sn() {
	local helper="${READ_PRODUCT_IDENTITY:-/usr/libexec/board/read-product-identity.sh}"
	[ -x "$helper" ] || return 1
	sn="$("$helper" sn 2>/dev/null || true)"
	sn="$(printf '%s' "$sn" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	[ -n "$sn" ] || return 1
	printf '%s\n' "$sn"
}

read_cpuinfo_serial() {
	[ -r /proc/cpuinfo ] || return 1
	serial="$(awk -F: '/^[[:space:]]*Serial[[:space:]]*:/ {
		gsub(/^[ \t]+/, "", $2)
		print $2
		exit
	}' /proc/cpuinfo)"
	serial="$(printf '%s' "$serial" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
	[ -n "$serial" ] || return 1
	printf '%s\n' "$serial"
}

read_dt_serial() {
	for p in /proc/device-tree/serial-number /sys/firmware/devicetree/base/serial-number; do
		[ -r "$p" ] || continue
		serial="$(tr -d '\0' <"$p")"
		serial="$(printf '%s' "$serial" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		[ -n "$serial" ] || continue
		printf '%s\n' "$serial"
		return 0
	done
	return 1
}

# ChipID: Rockchip SoC id from cpuinfo first. DT serial-number is a separate
# binding factor (and may be a short/wrong string on some boards).
read_chip_id() {
	if serial="$(read_cpuinfo_serial 2>/dev/null)"; then
		printf '%s\n' "$serial"
		return 0
	fi

	if serial="$(read_dt_serial 2>/dev/null)"; then
		printf '%s\n' "$serial"
		return 0
	fi

	if [ -r /etc/machine-id ]; then
		printf 'lws-%s\n' "$(cat /etc/machine-id)"
		return 0
	fi

	printf 'lws-unknown\n'
}

if [ "$CHIP_ONLY" -eq 0 ]; then
	serial="$(read_vendor_sn 2>/dev/null || true)"
	if [ -n "$serial" ]; then
		printf '%s\n' "$serial"
		exit 0
	fi
fi

read_chip_id
