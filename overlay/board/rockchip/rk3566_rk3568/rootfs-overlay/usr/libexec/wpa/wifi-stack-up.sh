#!/bin/sh
# Bring up deferred Wi-Fi stack for HMI (not enabled at boot).
# Starts wlan-wpa.service so wpa_supplicant survives hmi.service stop/restart.
# Usage: wifi-stack-up.sh
set -eu

IFACE="${LWS_WLAN_IFACE:-}"
WPA_CONF="${LWS_WPA_CONF:-/var/lib/wpa_supplicant/wpa_supplicant.conf}"
CTRL_DIR=/var/run/wpa_supplicant
LIB_DIR=/var/lib/wpa_supplicant
UNIT=wlan-wpa.service
IFACE_FILE=/run/wpa-wlan.iface

log() {
	echo "wifi-stack-up: $*" >&2
}

mkdir -p "$LIB_DIR" "$CTRL_DIR"

if [ ! -f "$WPA_CONF" ]; then
	cat >"$WPA_CONF" <<'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root
update_config=1
country=CN
EOF
	chmod 600 "$WPA_CONF"
fi

# Load SDIO Wi-Fi via board OEM modem helper (profile / oem.env / wrapper).
resolve_wifi_modem() {
	if [ -n "${WIFI_MODEM_HELPER:-}" ] && [ -x "$WIFI_MODEM_HELPER" ]; then
		printf '%s\n' "$WIFI_MODEM_HELPER"
		return 0
	fi
	if [ -f /run/hmi/oem.env ]; then
		# shellcheck source=/dev/null
		. /run/hmi/oem.env
		if [ -n "${WIFI_MODEM_HELPER:-}" ] && [ -x "$WIFI_MODEM_HELPER" ]; then
			printf '%s\n' "$WIFI_MODEM_HELPER"
			return 0
		fi
	fi
	if [ -f /run/hmi/board_profile.json ]; then
		p="$(sed -n 's/.*"wifi_modem"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /run/hmi/board_profile.json | head -1)"
		if [ -n "$p" ] && [ -x "$p" ]; then
			printf '%s\n' "$p"
			return 0
		fi
	fi
	if [ -x /usr/libexec/bluetooth/wifibt-bringup.sh ]; then
		printf '%s\n' /usr/libexec/bluetooth/wifibt-bringup.sh
		return 0
	fi
	return 1
}

MODEM="$(resolve_wifi_modem)" || {
	log "wifi modem helper missing"
	exit 1
}
log "modem helper $MODEM"
"$MODEM" || {
	log "wifibt-bringup failed"
	exit 1
}
detect_wlan() {
	for d in /sys/class/net/*; do
		[ -e "$d" ] || continue
		name="$(basename "$d")"
		case "$name" in
		lo|eth*|end*|sit*|ip6tnl*|tun*|tap*|dummy*|usb*) continue ;;
		esac
		if [ -d "$d/wireless" ] || [ -d "$d/phy80211" ]; then
			echo "$name"
			return 0
		fi
	done
	return 1
}

if [ -z "$IFACE" ]; then
	IFACE="$(detect_wlan || true)"
fi
if [ -z "$IFACE" ]; then
	IFACE=wlan0
fi

if [ ! -d "/sys/class/net/$IFACE" ]; then
	log "$IFACE missing; netdevs: $(ls /sys/class/net 2>/dev/null | tr '\n' ' ')"
	exit 1
fi

log "using iface $IFACE"
printf '%s\n' "$IFACE" >"$IFACE_FILE"
ip link set "$IFACE" up 2>/dev/null || true

if wpa_cli -i "$IFACE" status >/dev/null 2>&1 && \
	systemctl is-active --quiet "$UNIT" 2>/dev/null; then
	log "wpa_supplicant already controlling $IFACE ($UNIT active)"
	mkdir -p /var/lib/wpa_supplicant
	: >/var/lib/wpa_supplicant/wifi-wanted
	exit 0
fi

# Escape hmi.service cgroup: never start wpa_supplicant as a child of Demo.
# Stop D-Bus-activated stock daemon first (empty `wpa_supplicant -u`); it owns
# fi.w1.wpa_supplicant1 and blocks our -u -i instance. Unit is also masked in
# image build; stop remains for boards that still have an unmasked unit.
systemctl stop wpa_supplicant.service 2>/dev/null || true
systemctl reset-failed "$UNIT" 2>/dev/null || true
if ! systemctl start "$UNIT"; then
	log "$UNIT failed to start"
	systemctl status "$UNIT" --no-pager -l 2>/dev/null | head -40 >&2 || true
	tail -40 /var/lib/wpa_supplicant/wpa_supplicant.log 2>/dev/null || true
	exit 1
fi

i=0
while [ "$i" -lt 40 ]; do
	if wpa_cli -i "$IFACE" status >/dev/null 2>&1; then
		log "ok ($IFACE via $UNIT)"
		mkdir -p /var/lib/wpa_supplicant
		: >/var/lib/wpa_supplicant/wifi-wanted
		exit 0
	fi
	if systemctl is-failed --quiet "$UNIT" 2>/dev/null; then
		log "$UNIT failed"
		systemctl status "$UNIT" --no-pager -l 2>/dev/null | head -40 >&2 || true
		tail -40 /var/lib/wpa_supplicant/wpa_supplicant.log 2>/dev/null || true
		exit 1
	fi
	i=$((i + 1))
	sleep 0.25
done

log "wpa_cli not ready on $IFACE"
systemctl status "$UNIT" --no-pager -l 2>/dev/null | head -40 >&2 || true
tail -40 /var/lib/wpa_supplicant/wpa_supplicant.log 2>/dev/null || true
exit 1
