#!/bin/sh
# Tear down HMI-managed Wi-Fi radio (leave units boot-deferred).
# Usage: wifi-stack-down.sh
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"
if [ -f /run/lws-hmi-wlan.iface ]; then
	IFACE="$(tr -d '[:space:]' </run/lws-hmi-wlan.iface)"
	IFACE="${IFACE:-wlan0}"
fi

# Stop DHCP / clear addresses first (via dedicated unit when present).
if [ -x /usr/lib/lws-hmi/wlan0-dhcp.sh ]; then
	/usr/lib/lws-hmi/wlan0-dhcp.sh stop 2>/dev/null || true
fi

if command -v systemctl >/dev/null 2>&1; then
	systemctl stop lws-hmi-wlan0-dhcp.service 2>/dev/null || true
	systemctl stop lws-hmi-wpa.service 2>/dev/null || true
	systemctl reset-failed lws-hmi-wlan0-dhcp.service 2>/dev/null || true
	systemctl reset-failed lws-hmi-wpa.service 2>/dev/null || true
fi

if command -v wpa_cli >/dev/null 2>&1; then
	wpa_cli -i "$IFACE" disconnect 2>/dev/null || true
fi

# Leftover daemons from older images (started under hmi cgroup).
pkill -f "wpa_supplicant.*-i ${IFACE}" 2>/dev/null || true

if [ -d "/sys/class/net/$IFACE" ]; then
	ip link set "$IFACE" down 2>/dev/null || true
fi

rm -f /var/lib/lws-hmi/wifi-wanted
echo "wifi-stack-down: $IFACE down"
