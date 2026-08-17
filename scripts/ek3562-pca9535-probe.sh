#!/bin/sh
# Probe PCA9535 on ek3562 (i2c-1 0x20 → sysfs label 1-0020 / BASE≈495).
#
# Default is interactive (meter-friendly): wait for Enter before each step.
#
#   sh /userdata/pca9535-probe.sh              # step 0..15: HIGH → Enter → LOW → next
#   sh /userdata/pca9535-probe.sh step 8 10    # only offsets 8..10
#   sh /userdata/pca9535-probe.sh high 8       # hold one line HIGH until Enter
#   sh /userdata/pca9535-probe.sh auto [from to]  # timed sweep (still pauses before start)
#   sh /userdata/pca9535-probe.sh read [from to]
#   sh /userdata/pca9535-probe.sh quiet        # mute Debug console (+ wlan0 down)
#   sh /userdata/pca9535-probe.sh noisy        # restore printk / wlan0
#
# Multimeter: black→GND, red→one silk OUT*; run step; when it says HIGH, look at meter.
# Env: QUIET=0 to keep kernel logs; QUIET_WLAN=0 to leave Wi-Fi up.
set -u

SAVED_PRINTK=""
WLAN_WAS_UP=""

restore_console() {
	if [ -n "${SAVED_PRINTK:-}" ] && [ -w /proc/sys/kernel/printk ]; then
		# shellcheck disable=SC2086
		echo $SAVED_PRINTK >/proc/sys/kernel/printk 2>/dev/null || true
		SAVED_PRINTK=""
	fi
	if [ "${WLAN_WAS_UP:-}" = 1 ]; then
		ip link set wlan0 up 2>/dev/null || true
		WLAN_WAS_UP=""
	fi
}

quiet_console() {
	case "${QUIET:-1}" in
	0|false|no|off) return 0 ;;
	esac
	if [ -r /proc/sys/kernel/printk ] && [ -w /proc/sys/kernel/printk ]; then
		SAVED_PRINTK=$(cat /proc/sys/kernel/printk)
		echo "1 4 1 7" >/proc/sys/kernel/printk
		if command -v dmesg >/dev/null 2>&1; then
			dmesg -n 1 2>/dev/null || true
		fi
		echo "(console quiet: printk [$SAVED_PRINTK] → 1; restore on exit / noisy)" >&2
	fi
	case "${QUIET_WLAN:-1}" in
	0|false|no|off) ;;
	*)
		if ip link show wlan0 2>/dev/null | grep -q 'state UP'; then
			WLAN_WAS_UP=1
			ip link set wlan0 down 2>/dev/null || true
			echo "(wlan0 down for quieter serial; restore on exit / noisy)" >&2
		fi
		;;
	esac
	trap restore_console EXIT INT TERM HUP
}

BASE="${PCA9535_BASE:-}"
if [ -z "$BASE" ]; then
	for d in /sys/class/gpio/gpiochip*; do
		[ -e "$d/label" ] || continue
		lab=$(cat "$d/label" 2>/dev/null || true)
		if [ "$lab" = "1-0020" ]; then
			BASE=$(cat "$d/base")
			break
		fi
	done
fi
if [ -z "${BASE:-}" ]; then
	BASE=495
	echo "WARN: gpiochip label 1-0020 not found; using BASE=$BASE" >&2
fi

NGPIO=$(cat /sys/class/gpio/gpiochip"${BASE}"/ngpio 2>/dev/null || echo 16)
HOLD_S="${HOLD_S:-2}"

pause() {
	msg=${1:-Press Enter to continue…}
	printf '%s' "$msg" >&2
	read -r _
}

export_line() {
	n=$1
	[ -e "/sys/class/gpio/gpio${n}" ] || echo "$n" >/sys/class/gpio/export
}

unexport_line() {
	n=$1
	[ -e "/sys/class/gpio/gpio${n}" ] && echo "$n" >/sys/class/gpio/unexport 2>/dev/null || true
}

drive() {
	off=$1
	level=$2
	n=$((BASE + off))
	if [ "$off" -lt 0 ] || [ "$off" -ge "$NGPIO" ]; then
		echo "offset $off out of range 0..$((NGPIO - 1))" >&2
		return 1
	fi
	export_line "$n"
	echo out >"/sys/class/gpio/gpio${n}/direction"
	echo "$level" >"/sys/class/gpio/gpio${n}/value"
}

cmd="${1:-step}"
[ "$#" -gt 0 ] && shift

case "$cmd" in
quiet)
	QUIET=1
	quiet_console
	# Keep muted after this command returns
	trap - EXIT INT TERM HUP
	echo "$SAVED_PRINTK" >/tmp/pca9535-printk.saved 2>/dev/null || true
	echo "${WLAN_WAS_UP:-0}" >/tmp/pca9535-wlan.saved 2>/dev/null || true
	echo "Console muted. Restore: sh $0 noisy"
	echo "printk now: $(cat /proc/sys/kernel/printk 2>/dev/null)"
	exit 0
	;;
noisy)
	if [ -r /tmp/pca9535-printk.saved ]; then
		SAVED_PRINTK=$(cat /tmp/pca9535-printk.saved)
	else
		SAVED_PRINTK="7 4 1 7"
	fi
	if [ -r /tmp/pca9535-wlan.saved ] && [ "$(cat /tmp/pca9535-wlan.saved)" = 1 ]; then
		WLAN_WAS_UP=1
	fi
	restore_console
	rm -f /tmp/pca9535-printk.saved /tmp/pca9535-wlan.saved
	if command -v dmesg >/dev/null 2>&1; then
		dmesg -n 7 2>/dev/null || true
	fi
	echo "Console restored. printk: $(cat /proc/sys/kernel/printk 2>/dev/null)"
	exit 0
	;;
step|sweep)
	quiet_console
	from=${1:-0}
	to=${2:-$((NGPIO - 1))}
	echo "PCA9535 interactive probe  BASE=$BASE  offsets ${from}..${to}"
	echo "1) Black probe → GND   Red probe → one silk OUT* (or move per step)"
	echo "2) When a line is HIGH, meter should show ~0V → ~VCC if that silk matches"
	pause "Probes ready? Press Enter to start… "
	i=$from
	while [ "$i" -le "$to" ]; do
		drive "$i" 1
		echo ""
		echo ">>> HIGH  offset=$i  linux=$((BASE + i))  ← watch meter now"
		pause "    Enter = pull LOW and go to next (or Ctrl+C to abort)… "
		drive "$i" 0
		unexport_line $((BASE + i))
		echo "    LOW   offset=$i"
		i=$((i + 1))
	done
	echo "done"
	;;
auto)
	quiet_console
	from=${1:-0}
	to=${2:-$((NGPIO - 1))}
	echo "PCA9535 auto sweep BASE=$BASE ${from}..${to} HIGH ${HOLD_S}s each"
	pause "Probes ready? Press Enter to start auto sweep… "
	i=$from
	while [ "$i" -le "$to" ]; do
		drive "$i" 1
		echo ">>> HIGH offset=$i linux=$((BASE + i))"
		sleep "$HOLD_S"
		drive "$i" 0
		unexport_line $((BASE + i))
		i=$((i + 1))
	done
	echo "auto done"
	;;
high)
	quiet_console
	off=${1:?need offset}
	echo "Will drive offset=$off HIGH (linux=$((BASE + off)))"
	pause "Probes on the silk you care about? Enter to drive HIGH… "
	drive "$off" 1
	echo ">>> HIGH offset=$off — leave probes; Enter to LOW + exit"
	pause ""
	drive "$off" 0
	unexport_line $((BASE + off))
	echo "LOW / unexported"
	;;
low)
	off=${1:?need offset}
	drive "$off" 0
	unexport_line $((BASE + off))
	echo "offset=$off LOW + unexported"
	;;
read)
	from=${1:-0}
	to=${2:-$((NGPIO - 1))}
	i=$from
	while [ "$i" -le "$to" ]; do
		n=$((BASE + i))
		export_line "$n"
		echo in >"/sys/class/gpio/gpio${n}/direction"
		v=$(cat "/sys/class/gpio/gpio${n}/value")
		echo "offset=$i linux=$n dir=in value=$v"
		unexport_line "$n"
		i=$((i + 1))
	done
	;;
*)
	echo "Usage: $0 step [from to] | auto [from to] | high <off> | low <off> | read [from to]" >&2
	echo "       $0 quiet | noisy" >&2
	echo "Env: PCA9535_BASE HOLD_S QUIET=1 QUIET_WLAN=1" >&2
	exit 1
	;;
esac
