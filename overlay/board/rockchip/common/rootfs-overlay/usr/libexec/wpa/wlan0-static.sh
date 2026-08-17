#!/bin/sh
# Static IPv4 on wlan0 via networkd.
# Usage: wlan0-static.sh <address> <prefix> [gateway] [dns]
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"
ADDR="${1:-}"
PREFIX="${2:-}"
GATEWAY="${3:-}"
DNS="${4:-}"
PREF="${LWS_WLAN_IPV4_PREF:-/var/lib/wpa_supplicant/wlan0-ipv4}"

if [ -z "$ADDR" ] || [ -z "$PREFIX" ]; then
	echo "usage: wlan0-static.sh <address> <prefix> [gateway] [dns]" >&2
	exit 2
fi

mkdir -p "$(dirname "$PREF")"
{
	echo "mode=static"
	echo "address=${ADDR}"
	echo "prefix=${PREFIX}"
	[ -n "$GATEWAY" ] && echo "gateway=${GATEWAY}"
	[ -n "$DNS" ] && echo "dns=${DNS}"
} >"$PREF"

if command -v systemctl >/dev/null 2>&1 && \
	[ -f /etc/systemd/system/wlan-dhcp.service ]; then
	# Reuse oneshot unit ExecStart path — unit runs wlan0-dhcp.sh; call apply directly.
	:
fi
/usr/libexec/network/networkd-apply-ipv4.sh "$IFACE" "$PREF"
echo "wlan0-static: ${ADDR}/${PREFIX} on $IFACE (networkd)"
