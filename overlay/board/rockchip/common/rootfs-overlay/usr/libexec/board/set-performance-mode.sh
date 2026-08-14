#!/bin/sh
# Apply CPU/DMC/GPU load / thermal profile before HMI start.
#
# Modes (tokens):
#   performance — max clocks / snappy HMI (default)
#   balanced    — lower sustained SoC load and heat (CPU governor + mid OPP
#                 cap + deep cpuidle). All devfreq (GPU/NPU/DMC) stay on
#                 performance: GPU ondemand before Weston leaves a black
#                 desktop (wallpaper never paints); NPU DVFS spam (-22);
#                 DMC DVFS breaks VOP rate programming. Soft heat cut is
#                 Flutter continuous-paint policy in the App.
#
# Usage:
#   set-performance-mode.sh              # restore from power.conf (default performance)
#   set-performance-mode.sh performance  # apply + persist
#   set-performance-mode.sh balanced     # apply + persist
#
# Operator symlink: /usr/bin/set-power-mode (compat: set-performance-mode).
#
# On this BSP, classic /sys/.../cpu*/cpufreq may be absent (SCMI clocks);
# GPU/DMC still use devfreq. Missing knobs are skipped (do not fail the mode).
set -eu

POWER_CONF="${POWER_CONF:-/var/lib/hal/power.conf}"
# Mid OPP target as percent of cpuinfo_max_freq (design: ~50–70%).
BALANCED_MAX_PCT="${BALANCED_MAX_PCT:-60}"

read_mode_from_conf() {
	mode=performance
	if [ -f "$POWER_CONF" ]; then
		raw="$(
			grep -E '^[[:space:]]*mode=' "$POWER_CONF" 2>/dev/null |
				head -n1 |
				cut -d= -f2- |
				tr -d '[:space:]' || true
		)"
		case "$raw" in
		performance | balanced)
			mode="$raw"
			;;
		esac
	fi
	printf '%s\n' "$mode"
}

persist_mode() {
	mode="$1"
	mkdir -p "$(dirname "$POWER_CONF")"
	printf 'mode=%s\n' "$mode" >"$POWER_CONF"
}

set_governor_prefer() {
	gov_path="$1"
	shift
	avail="${gov_path%governor}available_governors"
	[ -f "$gov_path" ] || return 0
	[ -r "$avail" ] || return 0
	for want in "$@"; do
		if grep -qw "$want" "$avail" 2>/dev/null; then
			echo "$want" >"$gov_path" 2>/dev/null || true
			return 0
		fi
	done
}

# Balanced keeps every devfreq on performance (see header). Still rewrite so a
# prior experimental ondemand GPU/NPU/DMC state is cleared on mode apply.
apply_balanced_devfreq() {
	for gov in /sys/class/devfreq/*/governor; do
		[ -f "$gov" ] || continue
		set_governor_prefer "$gov" performance
	done
}

# Pick nearest available OPP to (max * BALANCED_MAX_PCT / 100).
pick_mid_freq() {
	max_freq="$1"
	shift
	[ "$#" -gt 0 ] || return 1
	[ -n "$max_freq" ] && [ "$max_freq" -gt 0 ] 2>/dev/null || return 1
	target=$((max_freq * BALANCED_MAX_PCT / 100))
	best=
	best_delta=
	for f in "$@"; do
		[ -n "$f" ] || continue
		case "$f" in
		*[!0-9]*) continue ;;
		esac
		delta=$((f - target))
		if [ "$delta" -lt 0 ]; then
			delta=$((-delta))
		fi
		if [ -z "$best" ] || [ "$delta" -lt "$best_delta" ]; then
			best="$f"
			best_delta="$delta"
		fi
	done
	[ -n "$best" ] || return 1
	printf '%s\n' "$best"
}

apply_cpu_max_freq_cap() {
	for policy in /sys/devices/system/cpu/cpu*/cpufreq /sys/devices/system/cpu/cpufreq/policy*; do
		[ -d "$policy" ] || continue
		max_path="$policy/scaling_max_freq"
		info_max="$policy/cpuinfo_max_freq"
		avail_path="$policy/scaling_available_frequencies"
		[ -f "$max_path" ] || continue
		[ -w "$max_path" ] || continue
		max_freq=
		if [ -r "$info_max" ]; then
			max_freq="$(cat "$info_max" 2>/dev/null || true)"
		fi
		freqs=
		if [ -r "$avail_path" ]; then
			# shellcheck disable=SC2046
			freqs="$(cat "$avail_path" 2>/dev/null || true)"
		fi
		# Fallback: use current scaling_max_freq as the uncapped ceiling.
		if [ -z "$max_freq" ]; then
			max_freq="$(cat "$max_path" 2>/dev/null || true)"
		fi
		# shellcheck disable=SC2086
		mid="$(pick_mid_freq "$max_freq" $freqs 2>/dev/null || true)"
		if [ -z "$mid" ] && [ -n "$max_freq" ]; then
			mid=$((max_freq * BALANCED_MAX_PCT / 100))
		fi
		[ -n "$mid" ] || continue
		echo "$mid" >"$max_path" 2>/dev/null || true
	done
}

clear_cpu_max_freq_cap() {
	for policy in /sys/devices/system/cpu/cpu*/cpufreq /sys/devices/system/cpu/cpufreq/policy*; do
		[ -d "$policy" ] || continue
		max_path="$policy/scaling_max_freq"
		info_max="$policy/cpuinfo_max_freq"
		[ -f "$max_path" ] || continue
		[ -w "$max_path" ] || continue
		if [ -r "$info_max" ]; then
			echo "$(cat "$info_max")" >"$max_path" 2>/dev/null || true
		fi
	done
}

set_deep_cpuidle_disabled() {
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
}

set_deep_cpuidle_enabled() {
	for name_file in /sys/devices/system/cpu/cpu*/cpuidle/state*/name; do
		[ -f "$name_file" ] || continue
		name="$(cat "$name_file" 2>/dev/null || true)"
		case "$name" in
		WFI | "")
			continue
			;;
		*)
			echo 0 >"${name_file%name}disable" 2>/dev/null || true
			;;
		esac
	done
}

apply_performance() {
	for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
		/sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
		set_governor_prefer "$gov" performance
	done
	for gov in /sys/class/devfreq/*/governor; do
		set_governor_prefer "$gov" performance
	done
	clear_cpu_max_freq_cap
	set_deep_cpuidle_disabled
}

apply_balanced() {
	for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor \
		/sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do
		set_governor_prefer "$gov" ondemand schedutil powersave
	done
	apply_balanced_devfreq
	apply_cpu_max_freq_cap
	set_deep_cpuidle_enabled
}

arg="${1:-}"
case "$arg" in
"")
	mode="$(read_mode_from_conf)"
	;;
performance | balanced)
	mode="$arg"
	persist_mode "$mode"
	;;
*)
	echo "usage: $(basename "$0") [performance|balanced]" >&2
	exit 2
	;;
esac

case "$mode" in
performance)
	apply_performance
	;;
balanced)
	apply_balanced
	;;
esac
