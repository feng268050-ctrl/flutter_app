#!/bin/sh
# Static IPv4 on eth0 via networkd.
# Usage: eth0-static.sh <address> <prefix> [gateway] [dns]
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
ADDR="${1:-}"
PREFIX="${2:-}"
GATEWAY="${3:-}"
DNS="${4:-}"
PREF="${LWS_ETH_IPV4_PREF:-/var/lib/network/eth0-ipv4}"

case "$IFACE" in
wlan0|usb0|lo)
	echo "eth0-static: refusing $IFACE" >&2
	exit 1
	;;
esac

if [ -z "$ADDR" ] || [ -z "$PREFIX" ]; then
	echo "usage: eth0-static.sh <address> <prefix> [gateway] [dns]" >&2
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

if [ -z "${LWS_ETH_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1 && \
	[ -f /etc/systemd/system/eth0-network.service ]; then
	systemctl reset-failed eth0-network.service 2>/dev/null || true
	systemctl start eth0-network.service
else
	LWS_ETH_IN_UNIT=1 /usr/libexec/network/apply-eth0.sh
fi

echo "eth0-static: ${ADDR}/${PREFIX} on $IFACE (networkd)"
