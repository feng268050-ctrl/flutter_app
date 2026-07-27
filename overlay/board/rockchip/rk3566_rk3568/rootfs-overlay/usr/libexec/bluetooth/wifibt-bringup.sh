#!/bin/sh
# Thin rootfs stub — board Wi-Fi/BT modem bringup lives on OEM (W2).
set -eu

HELPER=""
if [ -n "${WIFI_MODEM_HELPER:-}" ] && [ -x "$WIFI_MODEM_HELPER" ]; then
	HELPER="$WIFI_MODEM_HELPER"
elif [ -f /run/hmi/oem.env ]; then
	# shellcheck source=/dev/null
	. /run/hmi/oem.env
	if [ -n "${WIFI_MODEM_HELPER:-}" ] && [ -x "$WIFI_MODEM_HELPER" ]; then
		HELPER="$WIFI_MODEM_HELPER"
	fi
fi
if [ -z "$HELPER" ] && [ -f /run/hmi/board_profile.json ]; then
	HELPER="$(sed -n 's/.*"wifi_modem"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /run/hmi/board_profile.json | head -1)"
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	if [ -f /oem/manifest.json ]; then
		board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
		cand="/oem/${board_path}/helpers/wifibt-bringup.sh"
		[ -n "$board_path" ] && [ -x "$cand" ] && HELPER="$cand"
	fi
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	echo "wifibt-bringup: OEM helper missing" >&2
	exit 1
fi
exec "$HELPER" "$@"
