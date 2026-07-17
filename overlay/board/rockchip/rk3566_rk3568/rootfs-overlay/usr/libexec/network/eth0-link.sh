#!/bin/sh
# Admin up/down for board wired Ethernet (eth0). Usage: eth0-link.sh up|down
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
ACTION="${1:-}"

case "$IFACE" in
wlan0|usb0|lo)
	echo "eth0-link: refusing $IFACE" >&2
	exit 1
	;;
esac

if [ ! -d "/sys/class/net/$IFACE" ]; then
	echo "eth0-link: $IFACE missing (no wired netdev; check gmac/PHY DTS)" >&2
	exit 1
fi

case "$ACTION" in
up)
	if ! ip link set "$IFACE" up 2>/tmp/lws-eth-link.err; then
		err="$(cat /tmp/lws-eth-link.err 2>/dev/null || true)"
		rm -f /tmp/lws-eth-link.err
		echo "eth0-link: cannot up $IFACE: ${err:-unknown}" >&2
		echo "eth0-link: tip — dmesg | grep -i phy ; MDIO/PHY reset may be wrong (see kernel-evb-dts-deferred)" >&2
		exit 1
	fi
	rm -f /tmp/lws-eth-link.err
	echo "eth0-link: $IFACE up"
	;;
down)
	if command -v systemctl >/dev/null 2>&1; then
		systemctl stop eth0-network.service 2>/dev/null || true
		systemctl reset-failed eth0-network.service 2>/dev/null || true
	fi
	if [ -x /usr/libexec/network/eth0-dhcp.sh ]; then
		LWS_ETH_IFACE="$IFACE" LWS_ETH_IN_UNIT=1 \
			/usr/libexec/network/eth0-dhcp.sh stop 2>/dev/null || true
	fi
	ip link set "$IFACE" down 2>/dev/null || true
	rm -f /var/lib/network/eth0-wanted
	echo "eth0-link: $IFACE down"
	;;
*)
	echo "usage: eth0-link.sh up|down" >&2
	exit 2
	;;
esac
