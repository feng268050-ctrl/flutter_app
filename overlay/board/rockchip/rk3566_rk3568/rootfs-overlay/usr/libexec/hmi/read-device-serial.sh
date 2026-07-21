#!/bin/sh
# Stable per-board serial for USB gadget iSerial and host tooling.
# Default: factory sn from product.ini, then chip ID (DT / SoC / machine-id).
# --chip-id: chip ID only (skip product.ini).
set -eu

PRODUCT_INI="${PRODUCT_INI:-/var/lib/hmi/product.ini}"
CHIP_ONLY=0
case "${1:-}" in
--chip-id | --chip)
	CHIP_ONLY=1
	;;
esac

read_product_ini_sn() {
	[ -r "$PRODUCT_INI" ] || return 1
	awk -F= '
		/^[[:space:]]*#/ { next }
		/^[[:space:]]*sn[[:space:]]*=/ {
			v=$0
			sub(/^[^=]*=/, "", v)
			gsub(/\r/, "", v)
			gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
			if (v != "") { print v; exit 0 }
		}
	' "$PRODUCT_INI"
}

read_dt_serial() {
	for p in /proc/device-tree/serial-number /sys/firmware/devicetree/base/serial-number; do
		[ -r "$p" ] || continue
		tr -d '\0' <"$p"
		return 0
	done
	return 1
}

read_chip_id() {
	serial="$(read_dt_serial 2>/dev/null || true)"
	if [ -n "$serial" ]; then
		printf '%s\n' "$serial"
		return 0
	fi

	if [ -r /proc/cpuinfo ]; then
		serial="$(awk -F: '/^[[:space:]]*Serial[[:space:]]*:/ {
			gsub(/^[ \t]+/, "", $2)
			print $2
			exit
		}' /proc/cpuinfo)"
		if [ -n "$serial" ]; then
			printf '%s\n' "$serial"
			return 0
		fi
	fi

	if [ -r /etc/machine-id ]; then
		printf 'lws-%s\n' "$(cat /etc/machine-id)"
		return 0
	fi

	printf 'lws-unknown\n'
}

if [ "$CHIP_ONLY" -eq 0 ]; then
	serial="$(read_product_ini_sn 2>/dev/null || true)"
	if [ -n "$serial" ]; then
		printf '%s\n' "$serial"
		exit 0
	fi
fi

read_chip_id
