#!/bin/sh
# Tear down HMI-managed Wi-Fi radio (leave units boot-deferred).
# Usage: wifi-stack-down.sh
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"

# Stop DHCP / clear addresses first.
if [ -x /usr/lib/lws-hmi/wlan0-dhcp.sh ]; then
	/usr/lib/lws-hmi/wlan0-dhcp.sh stop 2>/dev/null || true
fi

if command -v wpa_cli >/dev/null 2>&1; then
	wpa_cli -i "$IFACE" disconnect 2>/dev/null || true
fi

# Kill only the wpa_supplicant bound to this iface conf when possible.
pkill -f "wpa_supplicant.*-i ${IFACE}" 2>/dev/null || true

if [ -d "/sys/class/net/$IFACE" ]; then
	ip link set "$IFACE" down 2>/dev/null || true
fi

echo "wifi-stack-down: $IFACE down"
