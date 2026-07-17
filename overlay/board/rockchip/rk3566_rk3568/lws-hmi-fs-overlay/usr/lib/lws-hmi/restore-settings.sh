#!/bin/sh
# Restore P2.1 hardware prefs AFTER hmi.service (see unit After=hmi).
# UI absolute priority: never run on the HMI critical path; Demo controllers
# watch *-wanted and show starting/connecting like a manual toggle.
set -eu

LIB=/var/lib/lws-hmi

log() {
	echo "restore-settings: $*"
}

soft() {
	# shellcheck disable=SC2068
	if "$@"; then
		return 0
	fi
	log "WARN: command failed: $*"
	return 0
}

# --- backlight / volume (cheap; HMI also re-applies) ---
if [ -f "$LIB/backlight-brightness" ]; then
	pct="$(tr -d '[:space:]' <"$LIB/backlight-brightness")"
	if [ -n "$pct" ] && [ -x /usr/lib/lws-hmi/change-backlight.sh ]; then
		log "backlight $pct%"
		soft /usr/lib/lws-hmi/change-backlight.sh "$pct"
	fi
else
	log "no backlight-brightness — skip backlight"
fi

# display-orientation is read by hmi-launch.sh — no action here.

if [ -f "$LIB/media-volume" ] && command -v amixer >/dev/null 2>&1; then
	vol="$(tr -d '[:space:]' <"$LIB/media-volume")"
	case "$vol" in
	''|*[!0-9]*) ;;
	*)
		if [ "$vol" -gt 100 ]; then
			vol=100
		fi
		log "media-volume $vol%"
		amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
		amixer -q sset 'DAC Playback Volume' "${vol}%" 2>/dev/null || \
			amixer -q sset 'Speaker Playback Volume' "${vol}%" 2>/dev/null || \
			amixer -q sset 'Playback Volume' "${vol}%" 2>/dev/null || \
			amixer -q sset 'Master' "${vol}%" 2>/dev/null || \
			log "WARN: amixer volume soft-fail"
		;;
	esac
fi

# --- Wi-Fi (sequential; unit already After=hmi + Nice/idle) ---
if [ -f "$LIB/wifi-wanted" ]; then
	log "wifi-wanted → wifi-stack-up"
	if /usr/lib/lws-hmi/wifi-stack-up.sh; then
		ipv4="$LIB/wlan0-ipv4"
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
				soft /usr/lib/lws-hmi/wlan0-static.sh "$addr" "${prefix:-24}" "${gw:-}" "${dns:-}"
			fi
			;;
		*)
			log "wlan0 dhcp"
			soft /usr/lib/lws-hmi/wlan0-dhcp.sh start
			;;
		esac
	else
		log "WARN: wifi-stack-up failed"
	fi
else
	log "no wifi-wanted — skip Wi-Fi"
fi

# --- eth0 ---
if [ -f "$LIB/eth0-wanted" ]; then
	log "eth0-wanted → lws-hmi-eth0.service"
	if command -v systemctl >/dev/null 2>&1; then
		soft systemctl reset-failed lws-hmi-eth0.service
		soft systemctl start lws-hmi-eth0.service
	else
		soft /usr/lib/lws-hmi/apply-eth0.sh
	fi
else
	log "no eth0-wanted — skip eth0"
fi

# --- BT ---
bt_wanted=0
if [ -f "$LIB/bt-wanted" ]; then
	bt_wanted=1
fi
a2dp="$LIB/bt-a2dp-sink"
if [ -f "$a2dp" ]; then
	tok="$(tr -d '[:space:]' <"$a2dp")"
	case "$tok" in
	1|on|true|yes)
		bt_wanted=1
		;;
	esac
fi
if [ "$bt_wanted" = 1 ]; then
	log "bt wanted → bt-stack-up"
	soft /usr/lib/lws-hmi/bt-stack-up.sh
else
	log "no bt-wanted / a2dp — skip Bluetooth"
fi

# HTTP proxy: app. LAN SSH: intentionally not restored.
log "done"
exit 0
