#!/bin/sh
# DHCP on board wired Ethernet only (never wlan0/usb0). Usage: eth0-dhcp.sh [start|stop]
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
ACTION="${1:-start}"
PIDFILE="/run/lws-hmi-dhcpcd-${IFACE}.pid"
TIMEOUT="${LWS_DHCP_TIMEOUT:-45}"

log() {
	echo "eth0-dhcp: $*" >&2
}

case "$IFACE" in
wlan0|usb0|lo)
	log "refusing $IFACE"
	exit 1
	;;
esac

have_ipv4() {
	ip -4 -o addr show dev "$IFACE" 2>/dev/null | grep -q 'inet '
}

wait_ipv4() {
	i=0
	while [ "$i" -lt "$TIMEOUT" ]; do
		if have_ipv4; then
			ip -4 -o addr show dev "$IFACE" | head -1 >&2 || true
			return 0
		fi
		i=$((i + 1))
		sleep 1
	done
	return 1
}

wait_carrier() {
	i=0
	while [ "$i" -lt 20 ]; do
		op="$(cat "/sys/class/net/$IFACE/operstate" 2>/dev/null || echo down)"
		case "$op" in
		up|unknown) return 0 ;;
		esac
		if [ "$(cat "/sys/class/net/$IFACE/carrier" 2>/dev/null || echo 0)" = "1" ]; then
			return 0
		fi
		i=$((i + 1))
		sleep 0.5
	done
	return 0
}

stop_dhcp() {
	managed=0
	if [ -f "$PIDFILE" ] || pgrep -f "dhcpcd.*${IFACE}" >/dev/null 2>&1; then
		managed=1
	fi
	if [ "$managed" = 1 ] && command -v dhcpcd >/dev/null 2>&1; then
		dhcpcd -k "$IFACE" 2>/dev/null || true
	fi
	if [ -f "$PIDFILE" ]; then
		kill "$(cat "$PIDFILE")" 2>/dev/null || true
		rm -f "$PIDFILE"
	fi
	pkill -f "dhcpcd.*${IFACE}" 2>/dev/null || true
	pkill -f "udhcpc.*${IFACE}" 2>/dev/null || true
}

case "$ACTION" in
stop)
	stop_dhcp
	log "stopped on $IFACE"
	exit 0
	;;
start) ;;
*)
	echo "usage: eth0-dhcp.sh [start|stop]" >&2
	exit 2
	;;
esac

if [ ! -d "/sys/class/net/$IFACE" ]; then
	log "$IFACE missing"
	exit 1
fi

stop_dhcp
if ! ip link set "$IFACE" up 2>/tmp/lws-eth-dhcp.err; then
	err="$(cat /tmp/lws-eth-dhcp.err 2>/dev/null || true)"
	rm -f /tmp/lws-eth-dhcp.err
	log "cannot up $IFACE: ${err:-unknown} (PHY/MDIO?)"
	exit 1
fi
rm -f /tmp/lws-eth-dhcp.err
ip addr flush dev "$IFACE" 2>/dev/null || true
wait_carrier || true

mkdir -p /var/db /var/lib/dhcpcd /run/dhcpcd 2>/dev/null || true

if command -v dhcpcd >/dev/null 2>&1; then
	log "dhcpcd -w -t $TIMEOUT $IFACE"
	DHCP_LOG="$(mktemp /tmp/lws-eth-dhcp-XXXXXX.log 2>/dev/null || echo /tmp/lws-eth-dhcp.log)"
	if ! dhcpcd -w -t "$TIMEOUT" --pidfile "$PIDFILE" "$IFACE" >"$DHCP_LOG" 2>&1; then
		log "dhcpcd exited non-zero"
	fi
	sed "s/^/eth0-dhcp: /" "$DHCP_LOG" >&2 || true
	rm -f "$DHCP_LOG"
	if have_ipv4; then
		log "dhcpcd OK on $IFACE"
		exit 0
	fi
	log "dhcpcd did not assign IPv4 — trying udhcpc"
	dhcpcd -k "$IFACE" 2>/dev/null || true
fi

if command -v udhcpc >/dev/null 2>&1; then
	log "udhcpc -i $IFACE"
	UDHCP_LOG="$(mktemp /tmp/lws-eth-udhcp-XXXXXX.log 2>/dev/null || echo /tmp/lws-eth-udhcp.log)"
	udhcpc -i "$IFACE" -n -q -t 5 -T 3 -A 2 >"$UDHCP_LOG" 2>&1 || true
	sed "s/^/eth0-dhcp: /" "$UDHCP_LOG" >&2 || true
	rm -f "$UDHCP_LOG"
	if wait_ipv4; then
		log "udhcpc OK on $IFACE"
		exit 0
	fi
fi

log "failed to obtain IPv4 on $IFACE"
ip link show "$IFACE" >&2 || true
ip -4 addr show "$IFACE" >&2 || true
exit 1
