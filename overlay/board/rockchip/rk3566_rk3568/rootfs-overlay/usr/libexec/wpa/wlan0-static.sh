#!/bin/sh
# Static IPv4 on wlan0 only. Usage:
#   wlan0-static.sh <address> <prefix> [gateway] [dns]
# Example: wlan0-static.sh 192.168.1.50 24 192.168.1.1 8.8.8.8
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"
ADDR="${1:-}"
PREFIX="${2:-}"
GATEWAY="${3:-}"
DNS="${4:-}"

case "$IFACE" in
eth0)
	echo "wlan0-static: refusing eth0" >&2
	exit 1
	;;
esac

if [ -z "$ADDR" ] || [ -z "$PREFIX" ]; then
	echo "usage: wlan0-static.sh <address> <prefix> [gateway] [dns]" >&2
	exit 2
fi

if [ ! -d "/sys/class/net/$IFACE" ]; then
	echo "wlan0-static: $IFACE missing" >&2
	exit 1
fi

# Stop DHCP so it cannot fight static.
if [ -x /usr/libexec/wpa/wlan0-dhcp.sh ]; then
	/usr/libexec/wpa/wlan0-dhcp.sh stop 2>/dev/null || true
fi

ip link set "$IFACE" up
ip addr flush dev "$IFACE" 2>/dev/null || true
ip addr add "${ADDR}/${PREFIX}" dev "$IFACE"

if [ -n "$GATEWAY" ]; then
	ip route replace default via "$GATEWAY" dev "$IFACE" 2>/dev/null || \
		ip route add default via "$GATEWAY" dev "$IFACE"
fi

if [ -n "$DNS" ]; then
	mkdir -p /var/lib/wpa_supplicant
	printf 'nameserver %s\n' "$DNS" >/var/lib/wpa_supplicant/wlan0-resolv.conf
	# Prefer resolvconf if present; else merge carefully into /etc/resolv.conf
	if command -v resolvconf >/dev/null 2>&1; then
		printf 'nameserver %s\n' "$DNS" | resolvconf -a "$IFACE" 2>/dev/null || true
	else
		# Keep other nameservers; ensure ours is present.
		if [ -f /etc/resolv.conf ] && grep -q "nameserver ${DNS}" /etc/resolv.conf 2>/dev/null; then
			:
		else
			printf 'nameserver %s\n' "$DNS" >>/etc/resolv.conf
		fi
	fi
fi

echo "wlan0-static: ${ADDR}/${PREFIX} on $IFACE"
/usr/libexec/wpa/wlan0-time-sync.sh 2>/dev/null || true
