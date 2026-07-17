#!/bin/sh
# Foreground wpa_supplicant for wlan-wpa.service (Type=simple).
# Usage: run-wpa.sh (started by the unit; iface from wifi-stack-up.sh).
set -eu

IFACE_FILE=/run/wpa-wlan.iface
WPA_CONF="${LWS_WPA_CONF:-/var/lib/wpa_supplicant/wpa_supplicant.conf}"
WPA_LOG=/var/lib/wpa_supplicant/wpa_supplicant.log

IFACE="${LWS_WLAN_IFACE:-}"
if [ -z "$IFACE" ] && [ -f "$IFACE_FILE" ]; then
	IFACE="$(tr -d '[:space:]' <"$IFACE_FILE")"
fi
IFACE="${IFACE:-wlan0}"

mkdir -p /var/lib/wpa_supplicant /var/run/wpa_supplicant
if [ ! -f "$WPA_CONF" ]; then
	cat >"$WPA_CONF" <<'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root
update_config=1
country=CN
EOF
	chmod 600 "$WPA_CONF"
fi

if [ ! -d "/sys/class/net/$IFACE" ]; then
	echo "run-wpa: $IFACE missing" >&2
	exit 1
fi

ip link set "$IFACE" up 2>/dev/null || true
echo "run-wpa: starting wpa_supplicant on $IFACE" >&2
exec /usr/sbin/wpa_supplicant -i "$IFACE" -c "$WPA_CONF" -D nl80211,wext -f "$WPA_LOG"
