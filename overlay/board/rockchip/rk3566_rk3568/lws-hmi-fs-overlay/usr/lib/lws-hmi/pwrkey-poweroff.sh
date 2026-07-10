#!/bin/sh
# Watch the board power key without pulling systemd-logind into the boot path.
set -u

LOCK_DIR=/run/lws-hmi-pwrkey-poweroff.lock

log() {
	echo "lws-hmi-pwrkey: $*"
}

event_name() {
	event="$1"
	name_file="/sys/class/input/$(basename "$event")/device/name"
	if [ -r "$name_file" ]; then
		cat "$name_file" 2>/dev/null
	else
		echo unknown
	fi
}

is_power_key_device() {
	event="$1"
	name="$(event_name "$event" | tr '[:upper:]' '[:lower:]')"
	case "$name" in
		*pwr*key*|*power*key*|*power\ button*|*gpio-keys*|*adc-keys*|*rk8*pwr*)
			return 0
			;;
	esac
	return 1
}

request_poweroff() {
	if mkdir "$LOCK_DIR" 2>/dev/null; then
		log "KEY_POWER pressed; requesting poweroff"
		/usr/lib/lws-hmi/shutdown.sh poweroff
	fi
}

listen_event_device() {
	event="$1"
	log "listening on $event ($(event_name "$event"))"

	while [ -r "$event" ]; do
		bytes="$(dd if="$event" bs=24 count=1 2>/dev/null | od -An -tx1 -v 2>/dev/null)" || break
		set -- $bytes
		[ "$#" -ge 24 ] || continue

		shift 16
		type_lo="$1"
		type_hi="$2"
		code_lo="$3"
		code_hi="$4"
		value_0="$5"
		value_1="$6"
		value_2="$7"
		value_3="$8"

		if [ "$type_lo:$type_hi:$code_lo:$code_hi:$value_0:$value_1:$value_2:$value_3" = "01:00:74:00:01:00:00:00" ]; then
			request_poweroff
		fi
	done

	log "stopped listening on $event"
}

while :; do
	for event in /dev/input/event*; do
		[ -e "$event" ] || continue
		if is_power_key_device "$event"; then
			listen_event_device "$event" &
			found=1
		fi
	done

	if [ "${found:-0}" -eq 1 ]; then
		wait
		found=0
	else
		log "waiting for pwrkey input device"
		sleep 1
	fi
done
