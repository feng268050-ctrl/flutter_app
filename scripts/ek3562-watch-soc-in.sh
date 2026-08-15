#!/bin/sh
# Watch SoC GPIOs for ek3562 silk IN* (not PCA9535).
# Confirmed map:
#   IN0=113 chip3/17 GPIO3_PC1
#   IN1=110 chip3/14 GPIO3_PB6
#   IN2=50  chip1/18 GPIO1_PC2
#   IN3=51  chip1/19 GPIO1_PC3
#
#   sh /userdata/watch-soc-in.sh
# Short INx to GND; note which number flips. Ctrl+C to stop.
# Override: WATCH_GPIOS="50 51 110 113" sh /userdata/watch-soc-in.sh
set -u

LIST="${WATCH_GPIOS:-50 51 110 113}"

for n in $LIST; do
	[ -e "/sys/class/gpio/gpio${n}" ] || echo "$n" >/sys/class/gpio/export 2>/dev/null || continue
	echo in >"/sys/class/gpio/gpio${n}/direction" 2>/dev/null || true
done

echo "watching:$LIST"
echo "expect: IN0→113 IN1→110 IN2→50 IN3→51"
echo "Ctrl+C to stop."

while true; do
	line=""
	for n in $LIST; do
		[ -e "/sys/class/gpio/gpio${n}/value" ] || continue
		v=$(cat "/sys/class/gpio/gpio${n}/value" 2>/dev/null) || continue
		line="$line ${n}=${v}"
	done
	echo "$line"
	sleep 1
done
