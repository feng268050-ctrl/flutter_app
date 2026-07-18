#!/bin/sh
# Foreground wpa_supplicant for wlan-wpa.service (Type=simple).
# Usage: run-wpa.sh (started by the unit; iface from wifi-stack-up.sh).
#
# Product contract: D-Bus (-u) is mandatory. UI/HAL live status subscribes to
# fi.w1.wpa_supplicant1; starting without -u leaves Streams silent.
set -eu

IFACE_FILE=/run/wpa-wlan.iface
WPA_CONF="${LWS_WPA_CONF:-/var/lib/wpa_supplicant/wpa_supplicant.conf}"
WPA_LOG=/var/lib/wpa_supplicant/wpa_supplicant.log

IFACE="${LWS_WLAN_IFACE:-}"
if [ -z "$IFACE" ] && [ -f "$IFACE_FILE" ]; then
	IFACE="$(tr -d '[:space:]' <"$IFACE_FILE")"
fi
IFACE="${IFACE:-wlan0}"

mkdir -p /var/lib/wpa_supplicant /var/run/wpa_supplicant
if [ ! -f "$WPA_CONF" ]; then
	cat >"$WPA_CONF" <<'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=root
update_config=1
country=CN
EOF
	chmod 600 "$WPA_CONF"
fi

if [ ! -d "/sys/class/net/$IFACE" ]; then
	echo "run-wpa: $IFACE missing" >&2
	exit 1
fi

if ! /usr/sbin/wpa_supplicant -h 2>&1 | grep -q -- '[[:space:]]-u[[:space:]]'; then
	echo "run-wpa: FATAL: wpa_supplicant has no -u (D-Bus)." >&2
	echo "run-wpa: enable BR2_PACKAGE_WPA_SUPPLICANT_DBUS and rebuild the package" >&2
	echo "run-wpa:   bash scripts/br-make-packages.sh wpa wpa_supplicant" >&2
	echo "run-wpa:   make build-rootfs && make upgrade" >&2
	exit 1
fi

ip link set "$IFACE" up 2>/dev/null || true

# Free D-Bus name if stock/dbus-activated `wpa_supplicant -u` still holds it.
# We have not exec'd yet, so any remaining wpa_supplicant is a conflict.
if busctl status fi.w1.wpa_supplicant1 >/dev/null 2>&1; then
	echo "run-wpa: releasing fi.w1.wpa_supplicant1 before start" >&2
	systemctl stop wpa_supplicant.service 2>/dev/null || true
	killall wpa_supplicant 2>/dev/null || true
	i=0
	while [ "$i" -lt 20 ]; do
		busctl status fi.w1.wpa_supplicant1 >/dev/null 2>&1 || break
		i=$((i + 1))
		sleep 0.1
	done
fi

echo "run-wpa: starting wpa_supplicant (D-Bus -u) on $IFACE" >&2
exec /usr/sbin/wpa_supplicant -u -i "$IFACE" -c "$WPA_CONF" -D nl80211,wext -f "$WPA_LOG"
