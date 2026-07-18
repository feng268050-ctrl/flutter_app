#!/bin/sh
# After phone↔HMI pairing: Trust non-HID remotes immediately.
#
# IMPORTANT (A2DP Sink / speaker role):
# Do NOT bluetoothctl-connect from the HMI after the phone pairs. That makes us
# the BR/EDR initiator and BlueZ runs SDP browse of the phone → on AIC8800:
#   search_cb: Function not implemented (38) / Host is down (112)
# The phone must initiate A2DP Source → our Sink (bluealsa MediaEndpoint).
# We only need Trust so AuthorizeService is quiet.
#
# IMPORTANT (HID / HOGP):
# Do NOT trust Classic HID (UUID 1124) or BLE HOGP (UUID 1812) here.
# HID Trust is owned by the HMI Pair/Connect path so AuthorizeService and BlueZ
# Policy ReconnectUUIDs apply after the user has paired once. Phone-pair Trust
# must not touch keyboards/mice (A2DP phone path stays non-initiator).
#
# Usage:
#   bt-trust-paired.sh           # trust paired non-HID remotes
#   bt-trust-paired.sh --connect # same as trust (connect intentionally ignored)
set -eu

log() {
	echo "bt-trust-paired: $*" >&2
}

is_hid_peripheral() {
	info="$1"
	echo "$info" | grep -qiE 'UUID:.*(Human Interface|00001124|00001812)' && return 0
	echo "$info" | grep -qiE 'Icon:.*(keyboard|mouse|input-)' && return 0
	return 1
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
		if is_hid_peripheral "$info"; then
			log "skip HID $addr (Trust owned by HMI Connect/Pair)"
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
