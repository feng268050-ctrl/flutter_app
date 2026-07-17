#!/bin/sh
# Apply media volume percent (0–100) via ALSA and persist for boot restore.
# Usage: change-volume <percent>
set -eu

PCT="${1:-}"
case "$PCT" in
''|*[!0-9]*)
	echo "usage: $0 <0-100>" >&2
	exit 2
	;;
esac
if [ "$PCT" -gt 100 ]; then
	PCT=100
fi

PREF_DIR=/var/lib/lws-hmi
PREF="$PREF_DIR/media-volume"
mkdir -p "$PREF_DIR"
printf '%s\n' "$PCT" >"$PREF"

if command -v amixer >/dev/null 2>&1; then
	amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
	amixer -q sset 'DAC Playback Volume' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Speaker Playback Volume' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Headphone Playback Volume' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Playback Volume' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Master Playback Volume' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Master' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'PCM' "${PCT}%" 2>/dev/null || \
		amixer -q sset 'Speaker' "${PCT}%" 2>/dev/null || \
		echo "change-volume: WARN amixer soft-fail (persisted $PREF)" >&2
else
	echo "change-volume: WARN amixer missing (persisted $PREF)" >&2
fi

echo "change-volume: $PCT%; persisted $PREF"
