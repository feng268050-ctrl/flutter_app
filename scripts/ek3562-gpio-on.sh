#!/bin/sh
# Drive exactly one PCA9535 line HIGH (turns all other exported probe lines LOW first).
#   sh /userdata/gpio-on.sh on  <offset>   # only this offset HIGH
#   sh /userdata/gpio-on.sh off <offset>   # LOW + unexport that line
#   sh /userdata/gpio-on.sh offall         # LOW + unexport 0..15
#   sh /userdata/gpio-on.sh which          # show which lines are currently exported
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

off_one() {
	n=$((BASE + $1))
	if [ -e "/sys/class/gpio/gpio${n}" ]; then
		echo out >"/sys/class/gpio/gpio${n}/direction" 2>/dev/null || true
		echo 0 >"/sys/class/gpio/gpio${n}/value" 2>/dev/null || true
		echo "$n" >/sys/class/gpio/unexport 2>/dev/null || true
	fi
}

off_all() {
	i=0
	while [ "$i" -lt "$NGPIO" ]; do
		off_one "$i"
		i=$((i + 1))
	done
}

cmd=${1:?}
off=${2:-}

case "$cmd" in
on)
	[ -n "$off" ] || { echo "need offset"; exit 1; }
	# Exclusive: clear every line, then drive only this one
	off_all
	n=$((BASE + off))
	echo "$n" >/sys/class/gpio/export 2>/dev/null || true
	echo out >"/sys/class/gpio/gpio${n}/direction"
	echo 1 >"/sys/class/gpio/gpio${n}/value"
	echo "ONLY HIGH offset=$off  linux=$n  BASE=$BASE  (all other probe lines off)"
	;;
off)
	[ -n "$off" ] || { echo "need offset"; exit 1; }
	off_one "$off"
	echo "OFF offset=$off"
	;;
offall)
	off_all
	echo "OFF all offsets 0..$((NGPIO - 1))"
	;;
which)
	i=0
	while [ "$i" -lt "$NGPIO" ]; do
		n=$((BASE + i))
		if [ -e "/sys/class/gpio/gpio${n}" ]; then
			d=$(cat "/sys/class/gpio/gpio${n}/direction")
			v=$(cat "/sys/class/gpio/gpio${n}/value")
			echo "offset=$i linux=$n dir=$d val=$v"
		fi
		i=$((i + 1))
	done
	;;
*)
	echo "usage: $0 on <off> | off <off> | offall | which" >&2
	exit 1
	;;
esac
