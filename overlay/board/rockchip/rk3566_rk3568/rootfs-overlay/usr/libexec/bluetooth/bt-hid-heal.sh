#!/bin/sh
# Heal Bluetooth HID (Classic HID / BLE HOGP) input for one address.
#
# Owns the board-specific path that desktop stacks usually get for free:
# stuck LE (Connected without usable input), Rockchip ADDR_TYPE Connect,
# and ConnectProfile(HOGP) when Trusted bond exists but /dev/input is gone.
#
# IMPORTANT (ynh960 / LE keyboards):
# - Connected=yes + ServicesResolved=no often means inbound ATT / GATT is still
#   settling — do NOT Disconnect immediately (that fights the peripheral).
# - ConnectProfile may return br-connection-page-timeout even when input-hog
#   already created uhid/evdev after LE Connect. Treat evdev as success.
# - Never ConnectProfile while ServicesResolved is still false.
#
# Usage: bt-hid-heal.sh AA:BB:CC:DD:EE:FF
# Exit: 0 = input ready or nothing to do (not trusted / not HID)
#       1 = heal attempted but input still missing
#       2 = usage / missing tools
set -eu

ADDR="${1:-}"
RUN_DIR="${LWS_BT_HID_RUN:-/run/bt-hid}"
HOLD_FILE="${LWS_BT_HID_HOLD:-$RUN_DIR/hold}"
HOG_UUID="00001812-0000-1000-8000-00805f9b34fb"
HID_UUID="00001124-0000-1000-8000-00805f9b34fb"
# Wait for inbound ATT / GATT before treating Connected+!SR as a zombie.
GATT_GRACE_SEC="${LWS_BT_HID_GATT_GRACE:-15}"
# After Connect / SR=yes, give input-hog time before ConnectProfile.
HOG_SETTLE_SEC="${LWS_BT_HID_HOG_SETTLE:-8}"

log() { echo "bt-hid-heal: $*" >&2; }

if [ -z "$ADDR" ]; then
	echo "usage: bt-hid-heal.sh AA:BB:CC:DD:EE:FF" >&2
	exit 2
fi

# Normalize to AA:BB:… uppercase for BlueZ paths.
ADDR=$(echo "$ADDR" | tr 'a-f' 'A-F')
BARE=$(echo "$ADDR" | tr ':' '_')
STATUS_FILE="$RUN_DIR/$BARE"
mkdir -p "$RUN_DIR"

write_status() {
	echo "$1" >"$STATUS_FILE" 2>/dev/null || true
}

# HMI pair/disconnect/remove sets hold; loop skips. Explicit FORCE=1 for
# one-shot heal from HMI after Pair (still OK while hold is set).
if [ "${LWS_BT_HID_FORCE:-0}" != "1" ] && [ -f "$HOLD_FILE" ]; then
	write_status "idle"
	exit 0
fi

if ! command -v busctl >/dev/null 2>&1; then
	log "busctl missing"
	exit 2
fi

if ! systemctl is-active --quiet bluetooth.service 2>/dev/null; then
	write_status "idle"
	exit 0
fi

# Ensure UHID for HOGP.
if [ ! -e /dev/uhid ]; then
	modprobe uhid 2>/dev/null || true
fi

dev_path() {
	# Prefer fixed hci0 path — busctl tree walks GATT chars and logs Notifying.
	p="/org/bluez/hci0/dev_${BARE}"
	if busctl get-property org.bluez "$p" org.bluez.Device1 Address >/dev/null 2>&1; then
		echo "$p"
		return
	fi
	busctl tree org.bluez --list 2>/dev/null | grep -E "/dev_${BARE}\$" | head -1 || true
}

has_uuid() {
	echo "$1" | grep -qi "$2"
}

# True when a Bluetooth (uhid) HID node for ADDR exists — never USB mice.
evdev_present() {
	want=$(echo "$ADDR" | tr 'A-Z' 'a-z')
	found=""
	for d in /sys/class/input/event*/device; do
		[ -d "$d" ] || continue
		uniq=$(cat "$d/uniq" 2>/dev/null | tr 'A-Z' 'a-z' || true)
		if [ -n "$uniq" ] && [ "$uniq" = "$want" ]; then
			n=$(cat "$d/name" 2>/dev/null || true)
			found="$found $n"
			continue
		fi
		real=$(readlink -f "$d" 2>/dev/null || true)
		case "$real" in
		*uhid*)
			n=$(cat "$d/name" 2>/dev/null || true)
			case "$n" in
			*[Kk]eyboard* | *[Mm]ouse* | *QM002*) found="$found $n" ;;
			esac
			;;
		esac
	done
	[ -n "$found" ]
}

finish_ready() {
	log "OK input ready for $ADDR"
	write_status "ready"
	exit 0
}

# Fast path: input already up — no bluetoothctl / no GATT walks.
if evdev_present; then
	write_status "ready"
	exit 0
fi

# Poll until evdev appears or timeout (seconds). Returns 0 if ready.
wait_evdev() {
	secs="$1"
	i=0
	while [ "$i" -lt "$secs" ]; do
		if evdev_present; then
			return 0
		fi
		sleep 1
		i=$((i + 1))
	done
	evdev_present
}

PATH_OBJ=$(dev_path)
if [ -z "$PATH_OBJ" ]; then
	# No Device1 — BlueZ may still reconnect via Policy; nothing to heal yet.
	write_status "idle"
	exit 0
fi

# Device1 props only — never `bluetoothctl info` (floods characteristic_get_notifying).
TRUSTED=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 Trusted 2>/dev/null || true)
case "$TRUSTED" in
*true*) ;;
*)
	write_status "idle"
	exit 0
	;;
esac

UUIDS=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 UUIDs 2>/dev/null || true)
ICON=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 Icon 2>/dev/null || true)
# Only heal HID/HOGP — never initiate Connect to phones (A2DP Sink role).
if ! has_uuid "$UUIDS" "1812" && ! has_uuid "$UUIDS" "1124"; then
	case "$ICON" in
	*keyboard* | *mouse* | *input-*) ;;
	*)
		write_status "idle"
		exit 0
		;;
	esac
fi

write_status "healing"
log "heal $ADDR (Trusted HID, no BT evdev)"

# Rockchip ADDR_TYPE: random|public → LE; bredr → Classic; auto → bluetoothd pick.
addr_type() {
	atype=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 AddressType 2>/dev/null | \
		sed -n 's/.*"\([^"]*\)".*/\1/p' || true)
	if has_uuid "$UUIDS" "1124" && ! has_uuid "$UUIDS" "1812"; then
		echo "bredr"
		return
	fi
	if has_uuid "$UUIDS" "1812"; then
		case "$atype" in
		random | public) echo "$atype" ;;
		*) echo "random" ;;
		esac
		return
	fi
	echo "auto"
}

ATYPE=$(addr_type)
log "AddressType arg=$ATYPE"

get_bool() {
	busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 "$1" 2>/dev/null || true
}

refresh_path() {
	PATH_OBJ=$(dev_path)
}

CONN=$(get_bool Connected)
SR=$(get_bool ServicesResolved)

case "$CONN" in
*true*)
	case "$SR" in
	*true*)
		log "link up ServicesResolved=yes — wait ${HOG_SETTLE_SEC}s for input-hog"
		if wait_evdev "$HOG_SETTLE_SEC"; then
			finish_ready
		fi
		;;
	*)
		# Likely inbound ATT / GATT in progress — wait before any Disconnect.
		log "Connected, ServicesResolved=no — wait ${GATT_GRACE_SEC}s (do not interrupt ATT)"
		i=0
		while [ "$i" -lt "$GATT_GRACE_SEC" ]; do
			if evdev_present; then
				finish_ready
			fi
			refresh_path
			[ -n "$PATH_OBJ" ] || break
			SR=$(get_bool ServicesResolved)
			case "$SR" in
			*true*)
				log "ServicesResolved=yes during grace"
				if wait_evdev "$HOG_SETTLE_SEC"; then
					finish_ready
				fi
				break
				;;
			esac
			CONN=$(get_bool Connected)
			case "$CONN" in
			*true*) ;;
			*)
				log "link dropped during grace — leave to BlueZ Policy / next pass"
				write_status "missing"
				exit 1
				;;
			esac
			sleep 1
			i=$((i + 1))
		done
		refresh_path
		[ -n "$PATH_OBJ" ] || {
			write_status "missing"
			exit 1
		}
		SR=$(get_bool ServicesResolved)
		case "$SR" in
		*true*) ;;
		*)
			# Truly stuck zombie: Trusted LE keyboards re-ATTACH within ~250ms
			# after plain Disconnect, so Connected never clears and GATT never
			# resolves. Untrust first (same as user Disconnect hold), then
			# Disconnect → Trust → Connect.
			log "still no ServicesResolved after grace — untrust/disc/trust/Connect s \"$ATYPE\""
			bluetoothctl untrust "$ADDR" >/dev/null 2>&1 || true
			busctl set-property org.bluez "$PATH_OBJ" org.bluez.Device1 Trusted b false 2>&1 || true
			busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Disconnect s "$ATYPE" 2>&1 || true
			j=0
			while [ "$j" -lt 10 ]; do
				CONN=$(get_bool Connected)
				case "$CONN" in
				*false*) break ;;
				esac
				busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Disconnect s "$ATYPE" 2>&1 || true
				sleep 1
				j=$((j + 1))
			done
			bluetoothctl trust "$ADDR" >/dev/null 2>&1 || true
			refresh_path
			[ -n "$PATH_OBJ" ] || {
				write_status "missing"
				exit 1
			}
			busctl set-property org.bluez "$PATH_OBJ" org.bluez.Device1 Trusted b true 2>&1 || true
			busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Connect s "$ATYPE" 2>&1 || \
				busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Connect s "auto" 2>&1 || true
			;;
		esac
		;;
	esac
	;;
*)
	# Link down — host Connect backup after BlueZ Policy window (caller spaces retries).
	log "Connect s \"$ATYPE\" (link down)"
	busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Connect s "$ATYPE" 2>&1 || \
		busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 Connect s "auto" 2>&1 || true
	;;
esac

# Wait for ServicesResolved (and success if evdev appears first).
i=0
while [ "$i" -lt 20 ]; do
	if evdev_present; then
		finish_ready
	fi
	refresh_path
	[ -n "$PATH_OBJ" ] || break
	SR=$(get_bool ServicesResolved)
	case "$SR" in
	*true*) break ;;
	esac
	sleep 1
	i=$((i + 1))
done

if evdev_present; then
	finish_ready
fi

refresh_path
SR=$(get_bool ServicesResolved)
case "$SR" in
*true*)
	# Prefer letting input-hog attach after GATT; ConnectProfile is last resort.
	log "ServicesResolved=yes — settle ${HOG_SETTLE_SEC}s before ConnectProfile"
	if wait_evdev "$HOG_SETTLE_SEC"; then
		finish_ready
	fi
	refresh_path
	[ -n "$PATH_OBJ" ] || {
		write_status "missing"
		exit 1
	}
	live_uuids=$(busctl get-property org.bluez "$PATH_OBJ" org.bluez.Device1 UUIDs 2>/dev/null || true)
	if has_uuid "$UUIDS" "1812" || has_uuid "$live_uuids" "1812"; then
		log "ConnectProfile HOGP (ignore page-timeout if evdev appears)"
		busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 ConnectProfile s "$HOG_UUID" 2>&1 || true
	fi
	if has_uuid "$UUIDS" "1124" || has_uuid "$live_uuids" "1124"; then
		log "ConnectProfile Classic HID"
		busctl call org.bluez "$PATH_OBJ" org.bluez.Device1 ConnectProfile s "$HID_UUID" 2>&1 || true
	fi
	# ConnectProfile often returns br-connection-page-timeout on AIC while hog is up.
	if wait_evdev 5; then
		finish_ready
	fi
	;;
*)
	log "ServicesResolved still no — skip ConnectProfile (would page-timeout)"
	;;
esac

if evdev_present; then
	finish_ready
fi

log "WARN still no BT evdev for $ADDR"
write_status "missing"
exit 1
