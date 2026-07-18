#!/bin/sh
# wlan0 DHCP via networkd (L3). L2 association stays with wpa.
# Usage: wlan0-dhcp.sh start|stop
set -eu

IFACE="${LWS_WLAN_IFACE:-wlan0}"
PREF="${LWS_WLAN_IPV4_PREF:-/var/lib/wpa_supplicant/wlan0-ipv4}"
ACTION="${1:-start}"

log() {
	echo "wlan0-dhcp: $*" >&2
}

case "$ACTION" in
stop)
	if command -v networkctl >/dev/null 2>&1; then
		networkctl down "$IFACE" 2>/dev/null || true
	fi
	rm -f "/etc/systemd/network/50-hmi-${IFACE}.network"
	networkctl reload 2>/dev/null || true
	if [ -z "${LWS_DHCP_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1; then
		systemctl stop wlan-dhcp.service 2>/dev/null || true
		systemctl reset-failed wlan-dhcp.service 2>/dev/null || true
	fi
	exit 0
	;;
start)
	mkdir -p "$(dirname "$PREF")"
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

	if [ -z "${LWS_DHCP_IN_UNIT:-}" ] && command -v systemctl >/dev/null 2>&1 && \
		[ -f /etc/systemd/system/wlan-dhcp.service ]; then
		systemctl reset-failed wlan-dhcp.service 2>/dev/null || true
		if systemctl start wlan-dhcp.service; then
			log "ok via wlan-dhcp.service"
			exit 0
		fi
		log "wlan-dhcp.service failed — direct apply"
	fi
	/usr/libexec/network/networkd-apply-ipv4.sh "$IFACE" "$PREF"
	;;
*)
	echo "usage: wlan0-dhcp.sh start|stop" >&2
	exit 2
	;;
esac
