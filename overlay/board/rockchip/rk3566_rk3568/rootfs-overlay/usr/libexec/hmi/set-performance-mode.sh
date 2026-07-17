#!/bin/sh
# Set CPU cpufreq and DMC/GPU devfreq governors to performance before HMI start.
set -eu

set_governor() {
	gov_path="$1"
	avail="${gov_path%governor}available_governors"
	[ -f "$gov_path" ] || return 0
	[ -r "$avail" ] || return 0
	if grep -qw performance "$avail" 2>/dev/null; then
		echo performance >"$gov_path" 2>/dev/null || true
	fi
}

for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
	set_governor "$gov"
done

for gov in /sys/class/devfreq/*/governor; do
	set_governor "$gov"
done
