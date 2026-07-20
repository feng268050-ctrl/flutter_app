#!/bin/sh
# Set CPU/DMC/GPU to performance-oriented mode before HMI start.
#
# On this BSP, classic /sys/.../cpu*/cpufreq may be absent (SCMI clocks);
# GPU/DMC still use devfreq. Separately, deep cpuidle (cpu-sleep) is entered
# heavily and adds wake latency that feels like whole-UI jank — disable it.
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

for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
	/sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
	set_governor "$gov"
done

for gov in /sys/class/devfreq/*/governor; do
	set_governor "$gov"
done

# Keep WFI; disable deeper idle (name != WFI).
for name_file in /sys/devices/system/cpu/cpu*/cpuidle/state*/name; do
	[ -f "$name_file" ] || continue
	name="$(cat "$name_file" 2>/dev/null || true)"
	case "$name" in
	WFI | "")
		continue
		;;
	*)
		echo 1 >"${name_file%name}disable" 2>/dev/null || true
		;;
	esac
done
