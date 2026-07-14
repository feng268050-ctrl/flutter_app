#!/bin/sh
# Set BlueALSA A2DP Sink soft-volume (0–100%). Demo volume knob calls this.
# Soft-volume lives in bluealsa — ALSA DAC mixer alone does not change BT loudness.
# Usage: bt-a2dp-volume.sh <percent>
set -eu

percent="${1:-}"
case "$percent" in
'' | *[!0-9]*)
	echo "bt-a2dp-volume: usage: $0 <0-100>" >&2
	exit 1
	;;
esac
if [ "$percent" -gt 100 ]; then
	percent=100
fi

PREF_DIR=/var/lib/lws-hmi
mkdir -p "$PREF_DIR"
echo "$percent" >"$PREF_DIR/bt-a2dp-volume"

if ! command -v busctl >/dev/null 2>&1; then
	echo "bt-a2dp-volume: busctl missing" >&2
	exit 0
fi

if ! busctl status org.bluealsa >/dev/null 2>&1; then
	exit 0
fi

# A2DP soft-volume: 0–127 per channel; encode as uint16 (L<<8 | R).
vol=$((percent * 127 / 100))
encoded=$(( (vol << 8) | vol ))

# Prefer ObjectManager; fall back to tree grep.
paths=""
managed="$(busctl call org.bluealsa /org/bluealsa org.freedesktop.DBus.ObjectManager GetManagedObjects 2>/dev/null || true)"
if [ -n "$managed" ]; then
	paths="$(printf '%s\n' "$managed" | grep -Eo '/org/bluealsa/[^"]+/a2dpsnk/[^"]+' | sort -u || true)"
fi
if [ -z "$paths" ]; then
	paths="$(busctl tree org.bluealsa 2>/dev/null | grep -Eo '/org/bluealsa/[^ ]+/a2dpsnk/[^ ]+' | sort -u || true)"
fi

set_count=0
for path in $paths; do
	# Keep SoftVolume on so Demo/phone scaling stays local (no AVRCP Absolute Volume write).
	busctl set-property org.bluealsa "$path" org.bluealsa.PCM1 SoftVolume b true \
		>/dev/null 2>&1 || true
	# Skip no-op sets (phone Absolute Volume / apply-loop can re-hit the same level).
	cur="$(busctl get-property org.bluealsa "$path" org.bluealsa.PCM1 Volume 2>/dev/null | awk '{print $2}' || true)"
	if [ "$cur" = "$encoded" ]; then
		set_count=$((set_count + 1))
		continue
	fi
	if busctl set-property org.bluealsa "$path" org.bluealsa.PCM1 Volume q "$encoded" \
		>/dev/null 2>&1; then
		set_count=$((set_count + 1))
	fi
done

if [ "$set_count" -eq 0 ]; then
	echo "bt-a2dp-volume: no A2DP PCM yet (saved $percent%)" >&2
	exit 0
fi

echo "bt-a2dp-volume: set $set_count PCM(s) → $percent%" >&2
