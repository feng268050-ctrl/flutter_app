#!/bin/sh
# Apply eth0 link + IPv4 from /var/lib/network/eth0-ipv4 (for eth0-network.service).
# Usage: apply-eth0.sh
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

export LWS_ETH_IFACE="$IFACE"
export LWS_ETH_IN_UNIT=1

/usr/libexec/network/eth0-link.sh up

mode=dhcp
address=
prefix=24
gateway=
dns=
if [ -f "$PREF" ]; then
	# shellcheck disable=SC2162
	while IFS='=' read key val; do
		key="$(echo "$key" | tr -d '[:space:]')"
		val="$(echo "$val" | tr -d '\r')"
		case "$key" in
		mode) mode="$(echo "$val" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')" ;;
		address) address="$(echo "$val" | tr -d '[:space:]')" ;;
		prefix) prefix="$(echo "$val" | tr -d '[:space:]')" ;;
		gateway) gateway="$(echo "$val" | tr -d '[:space:]')" ;;
		dns) dns="$(echo "$val" | tr -d '[:space:]')" ;;
		esac
	done <"$PREF"
fi

case "$mode" in
static)
	[ -n "$address" ] || {
		log "static mode missing address"
		exit 1
	}
	/usr/libexec/network/eth0-static.sh "$address" "${prefix:-24}" "${gateway:-}" "${dns:-}"
	;;
*)
	/usr/libexec/network/eth0-dhcp.sh start
	;;
esac

log "ok ($mode on $IFACE)"
mkdir -p /var/lib/network
: >/var/lib/network/eth0-wanted
