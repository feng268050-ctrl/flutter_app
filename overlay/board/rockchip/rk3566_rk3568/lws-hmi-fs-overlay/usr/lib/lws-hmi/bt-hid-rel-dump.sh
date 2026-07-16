#!/bin/sh
# Dump EV_REL (REL_X/REL_Y) from an evdev node without evtest.
# Usage: bt-hid-rel-dump.sh [/dev/input/eventN]
# Move the pointer: finger RIGHT should print mostly REL_X; DOWN mostly REL_Y.
set -eu

DEV="${1:-}"
if [ -z "$DEV" ]; then
	for n in /sys/class/input/event*/device/name; do
		[ -f "$n" ] || continue
		name=$(cat "$n" 2>/dev/null || true)
		case "$name" in
		*[Mm]ouse*|*QM002*|*Touchpad*|*trackpad*)
			ev=$(echo "$n" | sed 's|.*/\(event[0-9]*\)/.*|\1|')
			DEV="/dev/input/$ev"
			echo "bt-hid-rel-dump: auto $DEV ($name)"
			break
			;;
		esac
	done
fi
[ -n "$DEV" ] && [ -e "$DEV" ] || {
	echo "usage: $0 /dev/input/eventN" >&2
	exit 1
}

echo "bt-hid-rel-dump: reading $DEV for 3s — move RIGHT, then DOWN"
echo "bt-hid-rel-dump: expect RIGHT=>REL_X, DOWN=>REL_Y (swapped => device HID axes)"

# aarch64 input_event = 24 bytes. EV_REL=2, REL_X=0, REL_Y=1.
# Prefer hexdump; fall back to od.
dump_hex() {
	if command -v hexdump >/dev/null 2>&1; then
		timeout 3 hexdump -v -e '24/1 "%02x" "\n"' "$DEV" 2>/dev/null || true
	else
		timeout 3 cat "$DEV" 2>/dev/null | od -An -v -tx1 | \
			awk '{ for (i=1;i<=NF;i++) { printf "%s", $i; c++; if (c==24) { printf "\n"; c=0 } } }'
	fi
}

hex_u16_le() {
	# $1 = two hex bytes low high, e.g. 0200 -> 2
	lo=$(printf '%d' "0x$1")
	hi=$(printf '%d' "0x$2")
	echo $((lo + 256 * hi))
}

hex_s32_le() {
	b0=$(printf '%d' "0x$1")
	b1=$(printf '%d' "0x$2")
	b2=$(printf '%d' "0x$3")
	b3=$(printf '%d' "0x$4")
	val=$((b0 + 256 * b1 + 65536 * b2 + 16777216 * b3))
	if [ "$val" -ge 2147483648 ]; then
		val=$((val - 4294967296))
	fi
	echo "$val"
}

dump_hex | while IFS= read -r line; do
	[ "${#line}" -ge 48 ] || continue
	# bytes 16-17 type, 18-19 code, 20-23 value (each byte = 2 hex chars)
	t0=$(echo "$line" | cut -c33-34)
	t1=$(echo "$line" | cut -c35-36)
	c0=$(echo "$line" | cut -c37-38)
	c1=$(echo "$line" | cut -c39-40)
	v0=$(echo "$line" | cut -c41-42)
	v1=$(echo "$line" | cut -c43-44)
	v2=$(echo "$line" | cut -c45-46)
	v3=$(echo "$line" | cut -c47-48)
	type=$(hex_u16_le "$t0" "$t1")
	code=$(hex_u16_le "$c0" "$c1")
	[ "$type" = "2" ] || continue
	val=$(hex_s32_le "$v0" "$v1" "$v2" "$v3")
	[ "$val" != "0" ] || continue
	case "$code" in
	0) echo "REL_X $val" ;;
	1) echo "REL_Y $val" ;;
	*) echo "REL_$code $val" ;;
	esac
done

echo "bt-hid-rel-dump: done"
