#!/bin/sh
# DHCP on wlan0 only (never eth0). Usage: wlan0-dhcp.sh [start|stop]
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"
ACTION="${1:-start}"
PIDFILE="/run/lws-hmi-dhcpcd-${IFACE}.pid"
TIMEOUT="${LWS_DHCP_TIMEOUT:-45}"

log() {
	echo "wlan0-dhcp: $*" >&2
}

case "$IFACE" in
eth0|end0|usb0)
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
	# Only dhcpcd -k when something is managing IFACE. Otherwise dhcpcd logs
	# "dhcpcd is not running" to the journal even with stderr redirected.
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
	# Prefer dedicated unit so any leftover dhcpcd stays out of hmi cgroup.
	if [ -z "${LWS_DHCP_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1; then
		systemctl stop lws-hmi-wlan0-dhcp.service 2>/dev/null || true
		systemctl reset-failed lws-hmi-wlan0-dhcp.service 2>/dev/null || true
	fi
	stop_dhcp
	log "stopped on $IFACE"
	exit 0
	;;
start)
	# Demo Process.run → this script would leave dhcpcd in hmi.service cgroup;
	# re-enter via oneshot unit so push-app (stop hmi) does not kill Wi-Fi IP.
	if [ -z "${LWS_DHCP_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1 && \
		[ -f /etc/systemd/system/lws-hmi-wlan0-dhcp.service ]; then
		systemctl reset-failed lws-hmi-wlan0-dhcp.service 2>/dev/null || true
		if systemctl start lws-hmi-wlan0-dhcp.service; then
			if have_ipv4; then
				log "ok via lws-hmi-wlan0-dhcp.service"
				exit 0
			fi
			log "lws-hmi-wlan0-dhcp.service started but no IPv4 yet"
		else
			log "lws-hmi-wlan0-dhcp.service failed"
			systemctl status lws-hmi-wlan0-dhcp.service --no-pager -l 2>/dev/null | head -30 >&2 || true
		fi
		exit 1
	fi
	;;
*)
	echo "usage: wlan0-dhcp.sh [start|stop]" >&2
	exit 2
	;;
esac

if [ ! -d "/sys/class/net/$IFACE" ]; then
	log "$IFACE missing"
	exit 1
fi

stop_dhcp
ip link set "$IFACE" up 2>/dev/null || true
# Drop stale lease addresses so we do not look "connected" with a dead IP.
ip addr flush dev "$IFACE" 2>/dev/null || true
wait_carrier || true

mkdir -p /var/db /var/lib/dhcpcd /run/dhcpcd 2>/dev/null || true

if command -v dhcpcd >/dev/null 2>&1; then
	# Wait for lease (-w) up to TIMEOUT; keep managing the iface afterwards.
	# Do not use -b alone — Demo would show obtainingIp forever.
	log "dhcpcd -w -t $TIMEOUT $IFACE"
	DHCP_LOG="$(mktemp /tmp/lws-dhcp-XXXXXX.log 2>/dev/null || echo /tmp/lws-dhcp.log)"
	if ! dhcpcd -w -t "$TIMEOUT" --pidfile "$PIDFILE" "$IFACE" >"$DHCP_LOG" 2>&1; then
		log "dhcpcd exited non-zero"
	fi
	sed "s/^/wlan0-dhcp: /" "$DHCP_LOG" >&2 || true
	rm -f "$DHCP_LOG"
	if have_ipv4; then
		log "dhcpcd OK on $IFACE"
		/usr/lib/lws-hmi/wlan0-time-sync.sh 2>/dev/null || true
		exit 0
	fi
	log "dhcpcd did not assign IPv4 — trying udhcpc"
	dhcpcd -k "$IFACE" 2>/dev/null || true
fi

if command -v udhcpc >/dev/null 2>&1; then
	log "udhcpc -i $IFACE"
	UDHCP_LOG="$(mktemp /tmp/lws-udhcp-XXXXXX.log 2>/dev/null || echo /tmp/lws-udhcp.log)"
	udhcpc -i "$IFACE" -n -q -t 5 -T 3 -A 2 >"$UDHCP_LOG" 2>&1 || true
	sed "s/^/wlan0-dhcp: /" "$UDHCP_LOG" >&2 || true
	rm -f "$UDHCP_LOG"
	if wait_ipv4; then
		log "udhcpc OK on $IFACE"
		/usr/lib/lws-hmi/wlan0-time-sync.sh 2>/dev/null || true
		exit 0
	fi
fi

log "failed to obtain IPv4 on $IFACE"
ip link show "$IFACE" >&2 || true
ip -4 addr show "$IFACE" >&2 || true
wpa_cli -i "$IFACE" status 2>/dev/null | head -20 >&2 || true
exit 1
