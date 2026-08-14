#!/bin/sh
# Apply eth0 link + IPv4 via systemd-networkd (D11).
# Pref: /var/lib/network/eth0-ipv4
set -eu

IFACE="${LWS_ETH_IFACE:-eth0}"
PREF="${LWS_ETH_IPV4_PREF:-/var/lib/network/eth0-ipv4}"

log() {
	echo "apply-eth0: $*" >&2
}

case "$IFACE" in
wlan0|usb0|lo)
	log "refusing $IFACE"
	exit 1
	;;
esac

if [ ! -d "/sys/class/net/$IFACE" ]; then
	log "$IFACE missing"
	exit 1
fi

# Ensure a pref file exists (default DHCP).
if [ ! -f "$PREF" ]; then
	mkdir -p "$(dirname "$PREF")"
	printf 'mode=dhcp\n' >"$PREF"
fi

/usr/libexec/network/networkd-apply-ipv4.sh "$IFACE" "$PREF"

# IPC RTSP path: stmmac/sysctl/RPS/pause hygiene (no ring resize).
if [ -x /usr/libexec/network/eth0-tune.sh ]; then
	/usr/libexec/network/eth0-tune.sh "$IFACE" || log "WARN: eth0-tune.sh failed"
fi

mkdir -p /var/lib/network
: >/var/lib/network/eth0-wanted
log "ok"
