#!/bin/sh
# Stop BlueZ-ALSA A2DP Sink. Clears preference so stack re-up stays off by default.
# Usage: bt-a2dp-sink-down.sh
set -eu

PREF="${LWS_BT_A2DP_PREF:-/var/lib/lws-hmi/bt-a2dp-sink}"
mkdir -p "$(dirname "$PREF")"
echo 0 >"$PREF"

if command -v systemctl >/dev/null 2>&1; then
	systemctl stop bluealsa-aplay.service 2>/dev/null || true
	systemctl stop bluealsa.service 2>/dev/null || true
fi

echo "bt-a2dp-sink-down: done"
