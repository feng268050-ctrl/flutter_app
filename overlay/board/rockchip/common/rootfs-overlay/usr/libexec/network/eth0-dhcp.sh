#!/bin/sh
# eth0 DHCP via networkd. Usage: eth0-dhcp.sh start|stop
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
PREF="${LWS_ETH_IPV4_PREF:-/var/lib/network/eth0-ipv4}"
ACTION="${1:-start}"

case "$IFACE" in
wlan0|usb0|lo)
	echo "eth0-dhcp: refusing $IFACE" >&2
	exit 1
	;;
esac

log() {
	echo "eth0-dhcp: $*" >&2
}

case "$ACTION" in
stop)
	/usr/libexec/network/eth0-link.sh down
	exit 0
	;;
start)
	mkdir -p "$(dirname "$PREF")"
	# Preserve static fields but force dhcp mode for this helper.
	if [ -f "$PREF" ]; then
		grep -vE '^mode=' "$PREF" >"${PREF}.tmp" 2>/dev/null || true
		printf 'mode=dhcp\n' >"$PREF"
		if [ -f "${PREF}.tmp" ]; then
			grep -E '^(address|prefix|gateway|dns)=' "${PREF}.tmp" >>"$PREF" || true
			rm -f "${PREF}.tmp"
		fi
	else
		printf 'mode=dhcp\n' >"$PREF"
	fi

	if [ -z "${LWS_ETH_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1 && \
		[ -f /etc/systemd/system/eth0-network.service ]; then
		systemctl reset-failed eth0-network.service 2>/dev/null || true
		if systemctl start eth0-network.service; then
			log "ok via eth0-network.service"
			exit 0
		fi
		log "eth0-network.service failed — direct apply"
	fi
	LWS_ETH_IN_UNIT=1 /usr/libexec/network/apply-eth0.sh
	;;
*)
	echo "usage: eth0-dhcp.sh start|stop" >&2
	exit 2
	;;
esac
