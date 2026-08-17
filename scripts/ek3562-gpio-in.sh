#!/bin/sh
# Read PCA9535 lines (ek3562 OUT0–3 = offsets 0–3). IN* are SoC — use watch-soc-in.sh.
#
#   sh /userdata/gpio-in.sh read <offset>
#   sh /userdata/gpio-in.sh watch <offset>
#   sh /userdata/gpio-in.sh scan [from to]
#   sh /userdata/gpio-in.sh offall
set -u

BASE=495
for d in /sys/class/gpio/gpiochip*; do
	[ -e "$d/label" ] || continue
	if [ "$(cat "$d/label" 2>/dev/null)" = "1-0020" ]; then
		BASE=$(cat "$d/base")
		break
	fi
done
NGPIO=$(cat /sys/class/gpio/gpiochip"${BASE}"/ngpio 2>/dev/null || echo 16)

export_in() {
	off=$1
	n=$((BASE + off))
	[ -e "/sys/class/gpio/gpio${n}" ] || echo "$n" >/sys/class/gpio/export
	echo in >"/sys/class/gpio/gpio${n}/direction"
	echo "$n"
}

unexport_off() {
	n=$((BASE + $1))
	[ -e "/sys/class/gpio/gpio${n}" ] && echo "$n" >/sys/class/gpio/unexport 2>/dev/null || true
}

off_all() {
	i=0
	while [ "$i" -lt "$NGPIO" ]; do
		unexport_off "$i"
		i=$((i + 1))
	done
}

cmd=${1:?}
shift 2>/dev/null || true

case "$cmd" in
read)
	off=${1:?need offset}
	n=$(export_in "$off")
	v=$(cat "/sys/class/gpio/gpio${n}/value")
	echo "offset=$off linux=$n dir=in value=$v  BASE=$BASE"
	;;
watch)
	off=${1:?need offset}
	n=$(export_in "$off")
	echo "watching offset=$off (Ctrl+C to stop) — toggle IN silk to GND"
	trap 'unexport_off "$off"; exit 0' INT TERM
	while true; do
		v=$(cat "/sys/class/gpio/gpio${n}/value")
		echo "offset=$off value=$v"
		sleep 1
	done
	;;
scan)
	from=${1:-0}
	to=${2:-$((NGPIO - 1))}
	echo "scan BASE=$BASE offsets ${from}..${to} (all as inputs)"
	i=$from
	while [ "$i" -le "$to" ]; do
		n=$(export_in "$i")
		v=$(cat "/sys/class/gpio/gpio${n}/value")
		echo "offset=$i linux=$n value=$v"
		i=$((i + 1))
	done
	;;
offall)
	off_all
	echo "unexported 0..$((NGPIO - 1))"
	;;
*)
	echo "usage: $0 read <off> | watch <off> | scan [from to] | offall" >&2
	exit 1
	;;
esac
