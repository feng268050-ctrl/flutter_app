#!/bin/sh
# Diagnose BLE HOGP / Classic HID input path on device.
# Usage: bt-hid-check.sh [AA:BB:CC:DD:EE:FF]
# With ADDR: also try Device1.ConnectProfile(HOGP) and re-probe input nodes.
set -eu

ADDR="${1:-}"

log() { echo "bt-hid-check: $*"; }

log "kernel $(uname -r)"

if [ -e /dev/uhid ]; then
	log "OK /dev/uhid present (UHID available — built-in or module loaded)"
	ls -l /dev/uhid 2>/dev/null || true
else
	log "FAIL /dev/uhid missing — BLE HOGP cannot create keyboard/mouse nodes"
	log "  CONFIG_UHID must be y (or m + modprobe). Rebuild: make apply-overlay && make build-kernel && make build-rootfs && make upgrade"
fi

if modprobe -n uhid >/dev/null 2>&1; then
	log "uhid is available as a loadable module"
elif [ -e /dev/uhid ]; then
	log "uhid looks built-in (modprobe not needed)"
else
	log "uhid not loadable and /dev/uhid absent"
fi

if [ -r /proc/config.gz ]; then
	zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_UHID|CONFIG_BT_HIDP|CONFIG_HID=' || true
elif [ -r "/lib/modules/$(uname -r)/build/.config" ]; then
	grep -E 'CONFIG_UHID|CONFIG_BT_HIDP|CONFIG_HID=' \
		"/lib/modules/$(uname -r)/build/.config" 2>/dev/null || true
fi

log "input event names:"
for ev in /sys/class/input/event*/device/name; do
	[ -f "$ev" ] || continue
	printf '  %s = %s\n' "$(echo "$ev" | sed 's|.*/\(event[0-9]*\)/.*|\1|')" "$(cat "$ev" 2>/dev/null || echo '?')"
done

log "event nodes: $(ls /dev/input/event* 2>/dev/null | tr '\n' ' ')"

if [ -n "$ADDR" ] && command -v bluetoothctl >/dev/null 2>&1; then
	log "bluetoothctl info $ADDR (trimmed):"
	bluetoothctl info "$ADDR" 2>/dev/null | grep -iE \
		'Name:|Alias:|Icon:|Paired:|Bonded:|Trusted:|Connected:|UUID:|ServicesResolved:' || true

	BARE=$(echo "$ADDR" | tr 'a-f' 'A-F' | tr ':' '_')
	PATH_OBJ=$(busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_${BARE}\$" | head -1 || true)
	if [ -n "$PATH_OBJ" ]; then
		log "Device1 path: $PATH_OBJ"
		log "ServicesResolved / Connected (D-Bus):"
		busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 ServicesResolved 2>&1 || true
		busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 Connected 2>&1 || true
		log "interfaces (Input1 = HOGP attached):"
		busctl introspect org.bluez "$PATH_OBJ" 2>/dev/null | \
			grep -E 'org\.bluez\.(Device1|Input1|Battery1)' || true

		# Zombie LE (Connected without ServicesResolved) → ConnectProfile page-timeouts.
		# Policy keeps Trusted Connected sticky — Untrust so Disconnect sticks.
		SR=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 ServicesResolved 2>/dev/null || true)
		CONN=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 Connected 2>/dev/null || true)
		ATYPE=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 AddressType 2>/dev/null | sed -n 's/.*"\([^"]*\)".*/\1/p')
		log "AddressType=$ATYPE (info only)"
		case "$CONN" in *true*)
			case "$SR" in *false*|"")
				log "zombie LE: Untrust/Disconnect/Trust/Connect to force GATT…"
				busctl set-property org.bluez "$PATH_OBJ" org.bluez.Device1 Trusted b false 2>&1 || true
				busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Disconnect 2>&1 || true
				sleep 2
				busctl set-property org.bluez "$PATH_OBJ" org.bluez.Device1 Trusted b true 2>&1 || true
				busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Connect 2>&1 || true
				i=0
				while [ "$i" -lt 20 ]; do
					SR=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 ServicesResolved 2>/dev/null || true)
					case "$SR" in *true*) break ;; esac
					sleep 1
					i=$((i + 1))
				done
				log "after refresh: $SR"
				;;
			esac
			;;
		esac

		log "forcing ConnectProfile HOGP (00001812)…"
		busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 ConnectProfile s \
			"00001812-0000-1000-8000-00805f9b34fb" 2>&1 || true
		sleep 2
		log "interfaces after ConnectProfile:"
		busctl introspect org.bluez "$PATH_OBJ" 2>/dev/null | \
			grep -E 'org\.bluez\.(Device1|Input1|Battery1)' || true
		log "input names after ConnectProfile:"
		for ev in /sys/class/input/event*/device/name; do
			[ -f "$ev" ] || continue
			printf '  %s = %s\n' "$(echo "$ev" | sed 's|.*/\(event[0-9]*\)/.*|\1|')" "$(cat "$ev" 2>/dev/null || echo '?')"
		done
	else
		log "no org.bluez Device1 path for $ADDR (is it Connected?)"
	fi
fi

if command -v journalctl >/dev/null 2>&1; then
	log "recent bluetoothd hog/uhid lines:"
	journalctl -u bluetooth -n 120 --no-pager 2>/dev/null | \
		grep -iE 'uhid|hog|input-hog|HID|accept failed|ConnectProfile' | tail -30 || log "(none)"
fi

log "done"
