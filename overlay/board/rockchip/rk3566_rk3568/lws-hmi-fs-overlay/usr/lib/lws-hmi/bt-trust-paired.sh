#!/bin/sh
# After phone↔HMI pairing: Trust immediately.
#
# IMPORTANT (A2DP Sink / speaker role):
# Do NOT bluetoothctl-connect from the HMI after the phone pairs. That makes us
# the BR/EDR initiator and BlueZ runs SDP browse of the phone → on AIC8800:
#   search_cb: Function not implemented (38) / Host is down (112)
# The phone must initiate A2DP Source → our Sink (bluealsa MediaEndpoint).
# We only need Trust so AuthorizeService is quiet.
#
# Usage:
#   bt-trust-paired.sh           # trust paired remotes
#   bt-trust-paired.sh --connect # same as trust (connect intentionally ignored)
set -eu

log() {
	echo "bt-trust-paired: $*" >&2
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
	exit 0
fi

case "${1:-}" in
--connect | connect)
	log "note: --connect ignored in sink role (phone must initiate A2DP)"
	;;
esac

# bluetoothctl devices Paired  →  Device AA:BB:… Name
bluetoothctl devices Paired 2>/dev/null | while read -r _dev addr rest; do
	case "$addr" in
	*:*:*)
		info="$(bluetoothctl info "$addr" 2>/dev/null || true)"
		if ! echo "$info" | grep -qi 'Paired: yes'; then
			continue
		fi
		if ! echo "$info" | grep -qi 'Trusted: yes'; then
			log "trust $addr"
			bluetoothctl trust "$addr" >/dev/null 2>&1 || true
		fi
		# Drop stale remote SDP cache left by earlier failed reverse browse.
		for cache in /var/lib/bluetooth/*/cache/"$(echo "$addr" | tr 'a-f' 'A-F')"; do
			if [ -f "$cache" ]; then
				log "clear cache $cache"
				rm -f "$cache" || true
			fi
		done
		;;
	esac
done

exit 0
