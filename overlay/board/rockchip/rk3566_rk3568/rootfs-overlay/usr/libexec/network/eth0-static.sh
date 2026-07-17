#!/bin/sh
# Static IPv4 on board wired Ethernet only. Usage:
#   eth0-static.sh <address> <prefix> [gateway] [dns]
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
ADDR="${1:-}"
PREFIX="${2:-}"
GATEWAY="${3:-}"
DNS="${4:-}"

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

if [ ! -d "/sys/class/net/$IFACE" ]; then
	echo "eth0-static: $IFACE missing" >&2
	exit 1
fi

if [ -x /usr/libexec/network/eth0-dhcp.sh ]; then
	LWS_ETH_IFACE="$IFACE" /usr/libexec/network/eth0-dhcp.sh stop 2>/dev/null || true
fi

if ! ip link set "$IFACE" up 2>/tmp/lws-eth-static.err; then
	err="$(cat /tmp/lws-eth-static.err 2>/dev/null || true)"
	rm -f /tmp/lws-eth-static.err
	echo "eth0-static: cannot up $IFACE: ${err:-unknown} (PHY/MDIO?)" >&2
	exit 1
fi
rm -f /tmp/lws-eth-static.err
ip addr flush dev "$IFACE" 2>/dev/null || true
ip addr add "${ADDR}/${PREFIX}" dev "$IFACE"

if [ -n "$GATEWAY" ]; then
	ip route replace default via "$GATEWAY" dev "$IFACE" 2>/dev/null || \
		ip route add default via "$GATEWAY" dev "$IFACE"
fi

if [ -n "$DNS" ]; then
	mkdir -p /var/lib/network
	printf 'nameserver %s\n' "$DNS" >/var/lib/network/eth0-resolv.conf
	if command -v resolvconf >/dev/null 2>&1; then
		printf 'nameserver %s\n' "$DNS" | resolvconf -a "$IFACE" 2>/dev/null || true
	else
		if [ -f /etc/resolv.conf ] && grep -q "nameserver ${DNS}" /etc/resolv.conf 2>/dev/null; then
			:
		else
			printf 'nameserver %s\n' "$DNS" >>/etc/resolv.conf
		fi
	fi
fi

echo "eth0-static: ${ADDR}/${PREFIX} on $IFACE"
