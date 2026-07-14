#!/bin/sh
# Prepare onboard ALSA for BlueZ-ALSA A2DP Sink playback.
# Soft-stop local mpg123/aplay so they do not hold the PCM exclusive.
set -eu

log() {
	echo "bt-audio-prepare: $*" >&2
}

if command -v amixer >/dev/null 2>&1; then
	amixer sset 'Playback Path' 'RING_SPK_HP' >/dev/null 2>&1 || \
		log "Playback Path RING_SPK_HP soft-fail"
fi

# Demo speaker smoke opens mpg123 -R / aplay on default PCM.
pkill -TERM -x mpg123 2>/dev/null || true
pkill -TERM -x aplay 2>/dev/null || true
# Brief settle so ALSA releases before bluealsa-aplay may open hw.
sleep 0.2

# Keep classic inquiry/page receptive while media endpoints come up (iPhone window).
if command -v bluetoothctl >/dev/null 2>&1; then
	bluetoothctl pairable on >/dev/null 2>&1 || true
	bluetoothctl discoverable-timeout 180 >/dev/null 2>&1 || true
	bluetoothctl discoverable on >/dev/null 2>&1 || true
fi

log "ok"
