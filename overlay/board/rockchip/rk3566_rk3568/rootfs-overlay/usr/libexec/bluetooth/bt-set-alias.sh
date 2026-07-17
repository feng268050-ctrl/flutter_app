#!/bin/sh
# Set local adapter identity so phones do not see the default "BlueZ 5.xx".
# Usage: bt-set-alias.sh [alias]
set -eu

ALIAS="${1:-${LWS_BT_ALIAS:-lws-hmi}}"

log() {
	echo "bt-set-alias: $*" >&2
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
	log "bluetoothctl missing"
	exit 1
fi

# Wait for adapter.
i=0
while [ "$i" -lt 40 ]; do
	if bluetoothctl show >/dev/null 2>&1; then
		break
	fi
	i=$((i + 1))
	sleep 0.25
done

if ! bluetoothctl show >/dev/null 2>&1; then
	log "no adapter"
	exit 1
fi

bluetoothctl power on >/dev/null 2>&1 || true

# Prefer Alias (what phones see). system-alias where supported.
ok=0
if bluetoothctl system-alias "$ALIAS" >/tmp/lws-bt-alias.out 2>&1; then
	ok=1
elif bluetoothctl alias "$ALIAS" >/tmp/lws-bt-alias.out 2>&1; then
	ok=1
fi

# D-Bus fallback — works even when bluetoothctl alias subcommand differs.
if command -v busctl >/dev/null 2>&1; then
	for path in /org/bluez/hci0 /org/bluez/hci1; do
		if busctl get-property org.bluez "$path" org.bluez.Adapter1 Address >/dev/null 2>&1; then
			if busctl set-property org.bluez "$path" org.bluez.Adapter1 Alias s "$ALIAS" 2>/tmp/lws-bt-alias-bus.err; then
				ok=1
				log "busctl Alias=$ALIAS on $path"
			fi
			break
		fi
	done
fi

# Refresh inquiry data so scanners pick up the new name.
was_disc="$(bluetoothctl show 2>/dev/null | grep -i 'Discoverable:' | head -1 || true)"
if echo "$was_disc" | grep -qi yes; then
	bluetoothctl discoverable off >/dev/null 2>&1 || true
	sleep 0.2
	bluetoothctl discoverable on >/dev/null 2>&1 || true
fi

show="$(bluetoothctl show 2>/dev/null || true)"
alias_line="$(echo "$show" | grep -i 'Alias:' | head -1 || true)"
name_line="$(echo "$show" | grep -i '^[[:space:]]*Name:' | head -1 || true)"
log "Alias line: ${alias_line:-none}"
log "Name line: ${name_line:-none}"

case "$alias_line $name_line" in
*"$ALIAS"*)
	log "ok ($ALIAS)"
	exit 0
	;;
esac

if [ "$ok" = 1 ]; then
	log "commands succeeded but show still not $ALIAS — phone may cache old name; reboot BT / forget device"
	exit 0
fi

log "failed to set alias=$ALIAS"
cat /tmp/lws-bt-alias.out 2>/dev/null || true
exit 1
