#!/bin/sh
# Stable per-board serial for USB gadget iSerial (DT serial-number or SoC ID).
set -eu

read_dt_serial() {
	for p in /proc/device-tree/serial-number /sys/firmware/devicetree/base/serial-number; do
		[ -r "$p" ] || continue
		tr -d '\0' <"$p"
		return 0
	done
	return 1
}

serial="$(read_dt_serial 2>/dev/null || true)"
if [ -n "$serial" ]; then
	printf '%s\n' "$serial"
	exit 0
fi

if [ -r /proc/cpuinfo ]; then
	serial="$(awk -F: '/^[[:space:]]*Serial[[:space:]]*:/ {
		gsub(/^[ \t]+/, "", $2)
		print $2
		exit
	}' /proc/cpuinfo)"
	if [ -n "$serial" ]; then
		printf '%s\n' "$serial"
		exit 0
	fi
fi

if [ -r /etc/machine-id ]; then
	printf 'lws-%s\n' "$(cat /etc/machine-id)"
	exit 0
fi

printf 'lws-unknown\n'
