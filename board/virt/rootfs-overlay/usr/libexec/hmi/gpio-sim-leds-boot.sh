#!/bin/sh
# Boot stub: create /run/hmi/gpio-sim LED files before HMI (OEM helper may refresh).
set -eu
ROOT=/run/hmi/gpio-sim
mkdir -p "$ROOT/led_red" "$ROOT/led_yellow" "$ROOT/led_green" /run/hmi
for led in led_red led_yellow led_green; do
	[ -e "$ROOT/$led/value" ] || printf '0\n' >"$ROOT/$led/value"
	[ -e "$ROOT/$led/direction" ] || printf 'out\n' >"$ROOT/$led/direction"
done
