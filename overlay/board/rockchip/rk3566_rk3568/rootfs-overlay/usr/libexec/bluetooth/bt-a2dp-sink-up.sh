#!/bin/sh
# Start BlueZ-ALSA A2DP Sink (phone music → onboard speaker).
# Opt-in only — BT stack bring-up leaves this off unless preference is already 1.
# Usage: bt-a2dp-sink-up.sh
set -eu

log() {
	echo "bt-a2dp-sink-up: $*" >&2
}

PREF="${LWS_BT_A2DP_PREF:-/var/lib/bluetooth/bt-a2dp-sink}"

if ! command -v bluealsa >/dev/null 2>&1; then
	log "bluealsa missing"
	exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
	if ! systemctl is-active --quiet bluetooth.service; then
		log "bluetooth.service not active — enable adapter first"
		exit 1
	fi
	systemctl reset-failed bluealsa.service bluealsa-aplay.service 2>/dev/null || true
	if ! systemctl start bluealsa.service; then
		log "bluealsa.service failed"
		systemctl status bluealsa.service --no-pager -l 2>&1 | head -20 >&2 || true
		exit 1
	fi
	systemctl start bluealsa-aplay.service 2>/dev/null || \
		log "bluealsa-aplay soft-fail (A2DP may be silent)"
	# Apply last Demo/local volume if present.
	if [ -x /usr/libexec/bluetooth/bt-a2dp-volume.sh ] && [ -f /var/lib/bluetooth/bt-a2dp-volume ]; then
		vol="$(tr -d '[:space:]' </var/lib/bluetooth/bt-a2dp-volume 2>/dev/null || echo 80)"
		/usr/libexec/bluetooth/bt-a2dp-volume.sh "$vol" || true
	fi
else
	log "systemctl missing"
	exit 1
fi

mkdir -p "$(dirname "$PREF")"
echo 1 >"$PREF"
log "ok"
