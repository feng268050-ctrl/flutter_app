#!/bin/sh
# Long-running HID heal daemon: Trusted Classic HID / BLE HOGP only.
#
# BlueZ [Policy] ReconnectUUIDs is primary. This process is the board-level
# backup when Connected stays up but input-hog / uhid never attaches (or dies).
#
# Started by bt-stack-up.sh → bt-hid-heal.service; stopped with the stack.
#
# IMPORTANT: never call `bluetoothctl info` / `devices` / `busctl tree` on a
# healthy schedule — they walk GattCharacteristic1.Notifying and flood
# bluetoothd (characteristic_get_notifying). List bonds from
# /var/lib/bluetooth and probe Device1 props + sysfs only when needed.
set -eu

HEAL="${LWS_BT_HID_HEAL:-/usr/libexec/bluetooth/bt-hid-heal.sh}"
RUN_DIR="${LWS_BT_HID_RUN:-/run/bt-hid}"
HOLD_FILE="${LWS_BT_HID_HOLD:-$RUN_DIR/hold}"
INTERVAL="${LWS_BT_HID_HEAL_INTERVAL:-20}"
BACKOFF_DIR="$RUN_DIR/backoff"

log() { echo "bt-hid-heal-loop: $*" >&2; }

mkdir -p "$RUN_DIR" "$BACKOFF_DIR"

hmi_hold_active() {
	# HMI pair/disconnect/remove owns the link — do not fight it.
	[ -f "$HOLD_FILE" ]
}

backoff_allows() {
	addr_bare="$1"
	f="$BACKOFF_DIR/$addr_bare"
	[ -f "$f" ] || return 0
	next=$(cat "$f" 2>/dev/null || echo 0)
	now=$(date +%s)
	[ "$now" -ge "$next" ]
}

backoff_record_fail() {
	addr_bare="$1"
	f="$BACKOFF_DIR/$addr_bare"
	n=0
	[ -f "${f}.n" ] && n=$(cat "${f}.n" 2>/dev/null || echo 0)
	n=$((n + 1))
	echo "$n" >"${f}.n"
	shift_n="$n"
	[ "$shift_n" -gt 6 ] && shift_n=6
	delay=$((5 * (1 << (shift_n - 1))))
	[ "$delay" -gt 300 ] && delay=300
	echo $(($(date +%s) + delay)) >"$f"
	log "backoff ${delay}s after $n fail(s) for $addr_bare"
}

backoff_clear() {
	addr_bare="$1"
	rm -f "$BACKOFF_DIR/$addr_bare" "$BACKOFF_DIR/${addr_bare}.n"
}

evdev_ok() {
	addr="$1"
	want=$(echo "$addr" | tr 'A-Z' 'a-z')
	for d in /sys/class/input/event*/device; do
		[ -d "$d" ] || continue
		uniq=$(cat "$d/uniq" 2>/dev/null | tr 'A-Z' 'a-z' || true)
		if [ -n "$uniq" ] && [ "$uniq" = "$want" ]; then
			return 0
		fi
	done
	return 1
}

# Bonded Trusted HID from on-disk BlueZ store (no D-Bus GATT walk).
list_trusted_hid() {
	# Adapter dirs look like /var/lib/bluetooth/AA:BB:CC:DD:EE:FF/
	for base in /var/lib/bluetooth/*; do
		[ -d "$base" ] || continue
		case "$(basename "$base")" in
		*:*:*) ;;
		*) continue ;;
		esac
		for dir in "$base"/*; do
			[ -d "$dir" ] || continue
			addr=$(basename "$dir")
			case "$addr" in
			*:*:*) ;;
			*) continue ;;
			esac
			info="$dir/info"
			[ -f "$info" ] || continue
			grep -qE '^Trusted=true' "$info" 2>/dev/null || continue
			if grep -qiE 'UUID=00001124|UUID=00001812|Services=.*1812|Services=.*1124' "$info" 2>/dev/null || \
				grep -qiE '^Name=.*(Keyboard|Mouse|QM002|[Kk]eyboard|[Mm]ouse)' "$info" 2>/dev/null; then
				echo "$addr"
			fi
		done
	done
}

log "start interval=${INTERVAL}s heal=$HEAL"

sleep 3

while true; do
	if ! systemctl is-active --quiet bluetooth.service 2>/dev/null; then
		sleep "$INTERVAL"
		continue
	fi
	if [ ! -x "$HEAL" ]; then
		log "heal helper missing: $HEAL"
		sleep "$INTERVAL"
		continue
	fi
	if hmi_hold_active; then
		# Pair/Remove in progress — skip whole pass (avoids Disconnect races).
		sleep "$INTERVAL"
		continue
	fi

	list_trusted_hid | while read -r addr; do
		[ -n "$addr" ] || continue
		bare=$(echo "$addr" | tr 'a-f' 'A-F' | tr ':' '_')
		st=$(cat "$RUN_DIR/$bare" 2>/dev/null || true)
		if [ "$st" = "ready" ] && evdev_ok "$addr"; then
			continue
		fi
		if evdev_ok "$addr"; then
			echo ready >"$RUN_DIR/$bare" 2>/dev/null || true
			backoff_clear "$bare"
			continue
		fi
		if ! backoff_allows "$bare"; then
			continue
		fi
		if "$HEAL" "$addr"; then
			backoff_clear "$bare"
		else
			rc=$?
			if [ "$rc" -eq 1 ]; then
				backoff_record_fail "$bare"
			fi
		fi
	done

	sleep "$INTERVAL"
done
