#!/bin/sh
# Retry applying saved A2DP soft-volume until a stream PCM appears (or timeout).
set -eu
vol_file=/var/lib/lws-hmi/bt-a2dp-volume
helper=/usr/lib/lws-hmi/bt-a2dp-volume.sh
i=0
while [ "$i" -lt 15 ]; do
	if [ -f "$vol_file" ] && [ -x "$helper" ]; then
		vol="$(tr -d '[:space:]' <"$vol_file" 2>/dev/null || true)"
		case "$vol" in
		'' | *[!0-9]*) vol=80 ;;
		esac
		# Helper exits 0 even when no PCM; detect success via stderr "set N PCM"
		out="$("$helper" "$vol" 2>&1 || true)"
		echo "$out" >&2
		case "$out" in
		*'PCM(s)'*) exit 0 ;;
		esac
	fi
	i=$((i + 1))
	sleep 1
done
exit 0
