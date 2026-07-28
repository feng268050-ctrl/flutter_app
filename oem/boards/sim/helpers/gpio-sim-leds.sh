#!/bin/sh
# Create file-backed LED lines for P3.2 guest (gpio-sim / virt).
# HAL gpio.sim.json points at /run/hmi/gpio-sim/led_*/value.
set -eu

ROOT="${GPIO_SIM_ROOT:-/run/hmi/gpio-sim}"
mkdir -p "$ROOT/led_red" "$ROOT/led_yellow" "$ROOT/led_green"
for led in led_red led_yellow led_green; do
	val="$ROOT/$led/value"
	dir="$ROOT/$led/direction"
	if [ ! -e "$val" ]; then
		printf '0\n' >"$val"
	fi
	if [ ! -e "$dir" ]; then
		printf 'out\n' >"$dir"
	fi
done
echo "gpio-sim-leds: ready under $ROOT"
