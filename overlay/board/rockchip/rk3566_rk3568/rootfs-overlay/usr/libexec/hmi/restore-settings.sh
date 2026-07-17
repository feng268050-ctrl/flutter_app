#!/bin/sh
# Restore P2.1 hardware prefs AFTER hmi.service (see unit After=hmi).
set -eu

. /usr/libexec/hmi/paths.sh

log() {
	echo "restore-settings: $*"
}

soft() {
	if "$@"; then
		return 0
	fi
	log "WARN: command failed: $*"
	return 0
}

# --- backlight / volume (HMI state dir) ---
if [ -f "$VAR_HMI/backlight-brightness" ]; then
	pct="$(tr -d '[:space:]' <"$VAR_HMI/backlight-brightness")"
	if [ -n "$pct" ] && [ -x "$LIBEXEC_HMI/change-backlight.sh" ]; then
		log "backlight $pct%"
		soft "$LIBEXEC_HMI/change-backlight.sh" "$pct"
	fi
else
	log "no backlight-brightness — skip backlight"
fi

if [ -f "$VAR_HMI/media-volume" ]; then
	vol="$(tr -d '[:space:]' <"$VAR_HMI/media-volume")"
	case "$vol" in
	''|*[!0-9]*) ;;
	*)
		if [ "$vol" -gt 100 ]; then
			vol=100
		fi
		log "media-volume $vol%"
		if [ -x "$LIBEXEC_HMI/change-volume.sh" ]; then
			soft "$LIBEXEC_HMI/change-volume.sh" "$vol"
		elif command -v amixer >/dev/null 2>&1; then
			amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
			amixer -q sset 'DAC Playback Volume' "${vol}%" 2>/dev/null || \
				amixer -q sset 'Speaker Playback Volume' "${vol}%" 2>/dev/null || \
				amixer -q sset 'Playback Volume' "${vol}%" 2>/dev/null || \
				amixer -q sset 'Master' "${vol}%" 2>/dev/null || \
				log "WARN: amixer volume soft-fail"
		else
			log "WARN: change-volume/amixer missing"
		fi
		;;
	esac
fi

# --- Wi-Fi ---
if [ -f "$VAR_WPA/wifi-wanted" ]; then
	log "wifi-wanted → wifi-stack-up"
	if "$LIBEXEC_WPA/wifi-stack-up.sh"; then
		ipv4="$VAR_WPA/wlan0-ipv4"
		mode=dhcp
		if [ -f "$ipv4" ]; then
			mode="$(grep -E '^mode=' "$ipv4" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
		fi
		case "$mode" in
		static)
			addr="$(grep -E '^address=' "$ipv4" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
			prefix="$(grep -E '^prefix=' "$ipv4" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
			gw="$(grep -E '^gateway=' "$ipv4" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
			dns="$(grep -E '^dns=' "$ipv4" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
			if [ -n "$addr" ]; then
				log "wlan0 static $addr/$prefix"
				soft "$LIBEXEC_WPA/wlan0-static.sh" "$addr" "${prefix:-24}" "${gw:-}" "${dns:-}"
			fi
			;;
		*)
			log "wlan0 dhcp"
			soft "$LIBEXEC_WPA/wlan0-dhcp.sh" start
			;;
		esac
	else
		log "WARN: wifi-stack-up failed"
	fi
else
	log "no wifi-wanted — skip Wi-Fi"
fi

# --- eth0 ---
if [ -f "$VAR_NETWORK/eth0-wanted" ]; then
	log "eth0-wanted → eth0-network.service"
	if command -v systemctl >/dev/null 2>&1; then
		soft systemctl reset-failed eth0-network.service
		soft systemctl start eth0-network.service
	else
		soft "$LIBEXEC_NETWORK/apply-eth0.sh"
	fi
else
	log "no eth0-wanted — skip eth0"
fi

# --- BT ---
bt_wanted=0
if [ -f "$VAR_BLUETOOTH/bt-wanted" ]; then
	bt_wanted=1
fi
if [ -f "$VAR_BLUETOOTH/bt-a2dp-sink" ]; then
	tok="$(tr -d '[:space:]' <"$VAR_BLUETOOTH/bt-a2dp-sink")"
	case "$tok" in
	1|on|true|yes) bt_wanted=1 ;;
	esac
fi
if [ "$bt_wanted" = 1 ]; then
	log "bt wanted → bt-stack-up"
	soft "$LIBEXEC_BLUETOOTH/bt-stack-up.sh"
else
	log "no bt-wanted / a2dp — skip Bluetooth"
fi

log "done"
exit 0
