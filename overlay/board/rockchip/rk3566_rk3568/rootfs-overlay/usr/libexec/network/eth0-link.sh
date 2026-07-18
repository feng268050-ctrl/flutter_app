#!/bin/sh
# eth0 admin up/down via networkctl (networkd owns L3).
# Usage: eth0-link.sh up|down
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
ACTION="${1:-}"

case "$IFACE" in
wlan0|usb0|lo)
	echo "eth0-link: refusing $IFACE" >&2
	exit 1
	;;
esac

if ! command -v networkctl >/dev/null 2>&1; then
	echo "eth0-link: FATAL: networkctl missing (systemd-networkd required, D11)" >&2
	exit 1
fi

case "$ACTION" in
up)
	systemctl start systemd-networkd.service 2>/dev/null || true
	networkctl up "$IFACE" 2>/dev/null || ip link set "$IFACE" up
	;;
down)
	networkctl down "$IFACE" 2>/dev/null || ip link set "$IFACE" down
	# Stop oneshot unit state if it was RemainAfterExit.
	if [ -z "${LWS_ETH_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1; then
		systemctl stop eth0-network.service 2>/dev/null || true
		systemctl reset-failed eth0-network.service 2>/dev/null || true
	fi
	rm -f /var/lib/network/eth0-wanted
	;;
*)
	echo "usage: eth0-link.sh up|down" >&2
	exit 2
	;;
esac

echo "eth0-link: $ACTION $IFACE"
