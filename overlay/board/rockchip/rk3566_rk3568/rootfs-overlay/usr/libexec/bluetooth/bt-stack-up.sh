#!/bin/sh
# Bring up deferred Bluetooth for discoverable HMI (phone/PC → device).
# Usage: bt-stack-up.sh
set -eu

# Same resolve order as bt-set-alias.sh (arg N/A here).
ALIAS_FILE=/var/lib/bluetooth/adapter-alias
DEFAULT_ALIAS=lws-hmi
if [ -n "${LWS_BT_ALIAS:-}" ]; then
	ALIAS="$LWS_BT_ALIAS"
elif [ -f "$ALIAS_FILE" ]; then
	ALIAS="$(tr -d '\r' <"$ALIAS_FILE" | sed -n '1p' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
	[ -n "$ALIAS" ] || ALIAS="$DEFAULT_ALIAS"
else
	ALIAS="$DEFAULT_ALIAS"
fi

log() {
	echo "bt-stack-up: $*" >&2
}

# BlueZ requires system D-Bus + org.bluez policy (etc/dbus-1/system.d/bluetooth.conf).
if command -v systemctl >/dev/null 2>&1; then
	systemctl start dbus.socket 2>/dev/null || true
	systemctl start dbus.service 2>/dev/null || true
	systemctl reload dbus.service 2>/dev/null || \
		systemctl reload dbus 2>/dev/null || true
fi

if [ ! -f /etc/dbus-1/system.d/bluetooth.conf ] && \
	[ ! -f /usr/share/dbus-1/system.d/bluetooth.conf ]; then
	log "missing dbus bluetooth.conf — bluetoothd cannot own org.bluez"
	exit 1
fi

# Wi‑Fi+BT combo (AIC8800D80): SDIO wifi + UART hciattach first.
if [ -x /usr/libexec/bluetooth/wifibt-bringup.sh ]; then
	/usr/libexec/bluetooth/wifibt-bringup.sh || log "wifibt-bringup soft-fail (continue for BT)"
fi

# Non-AIC boards may still use Rockchip BT attach; harmless soft-fail on AIC.
if command -v wifibt-init.sh >/dev/null 2>&1; then
	wifibt-init.sh start_bt 2>&1 | while read -r line; do log "$line"; done || true
fi

if command -v systemctl >/dev/null 2>&1; then
	# D-Bus activation needs dbus-org.bluez.service (Alias only exists after enable;
	# we keep bluetooth boot-deferred, so ship a relative alias symlink in the overlay).
	if [ ! -e /etc/systemd/system/dbus-org.bluez.service ] && \
		[ ! -L /etc/systemd/system/dbus-org.bluez.service ] && \
		[ ! -e /usr/lib/systemd/system/dbus-org.bluez.service ] && \
		[ ! -L /usr/lib/systemd/system/dbus-org.bluez.service ]; then
		if [ -f /usr/lib/systemd/system/bluetooth.service ]; then
			ln -sfn ../../usr/lib/systemd/system/bluetooth.service \
				/etc/systemd/system/dbus-org.bluez.service 2>/dev/null || \
			ln -sfn /usr/lib/systemd/system/bluetooth.service \
				/etc/systemd/system/dbus-org.bluez.service 2>/dev/null || true
			systemctl daemon-reload 2>/dev/null || true
			log "installed dbus-org.bluez.service alias"
		fi
	fi
	systemctl reset-failed bluetooth.service 2>/dev/null || true
	# Prefer restart when a previous bluetoothd core-dump left the unit dead.
	if systemctl is-failed --quiet bluetooth.service 2>/dev/null || \
		! systemctl is-active --quiet bluetooth.service 2>/dev/null; then
		if ! systemctl restart bluetooth.service 2>/dev/null; then
			if ! systemctl start bluetooth.service; then
				log "bluetooth.service failed"
				systemctl status bluetooth.service --no-pager -l 2>&1 | head -40 >&2 || true
				exit 1
			fi
		fi
	fi
	if ! systemctl is-active --quiet bluetooth.service; then
		log "bluetooth.service not active"
		systemctl status bluetooth.service --no-pager -l 2>&1 | head -40 >&2 || true
		exit 1
	fi
fi

# HOGP keyboards/mice need /dev/uhid (CONFIG_UHID=y built-in, or =m + modprobe).
if [ -e /dev/uhid ]; then
	log "uhid ok (/dev/uhid present)"
elif modprobe uhid 2>/dev/null; then
	log "uhid module loaded"
else
	log "WARN: no /dev/uhid — BLE keyboard/mouse input will fail until kernel has CONFIG_UHID=y"
	log "  run: /usr/libexec/bluetooth/bt-hid-check.sh"
fi

if ! command -v bluetoothctl >/dev/null 2>&1; then
	log "bluetoothctl missing"
	exit 1
fi

i=0
while [ "$i" -lt 60 ]; do
	if bluetoothctl show >/dev/null 2>&1; then
		break
	fi
	i=$((i + 1))
	sleep 0.25
done

if ! bluetoothctl show >/dev/null 2>&1; then
	log "bluetoothctl show failed — no adapter / HCI not up"
	hciconfig -a 2>&1 | head -20 >&2 || true
	ps | grep -E 'brcm_patchram|rk_hciattach|rtk_hciattach|hciattach|rk_wifi_init' | grep -v grep >&2 || true
	dmesg 2>/dev/null | grep -iE 'hci|bluetooth|bt_|ttyS1|aic8800|patchram' | tail -30 >&2 || true
	exit 1
fi

bluetoothctl power on >/dev/null 2>&1 || true

# Replace BlueZ's default "BlueZ 5.xx" with product alias (Alias is what phones see).
if [ -x /usr/libexec/bluetooth/bt-set-alias.sh ]; then
	/usr/libexec/bluetooth/bt-set-alias.sh "$ALIAS" || log "bt-set-alias failed (name may stay BlueZ 5.xx)"
else
	bluetoothctl system-alias "$ALIAS" >/dev/null 2>&1 || \
		bluetoothctl alias "$ALIAS" >/dev/null 2>&1 || true
fi

bluetoothctl pairable on >/dev/null 2>&1 || true
# Classic inquiry requires Discoverable; default off until user enters pairing.
bluetoothctl discoverable-timeout 180 >/dev/null 2>&1 || true
bluetoothctl discoverable off >/dev/null 2>&1 || true

# Persistent Agent1 (must stay registered or phones discover but cannot pair).
if [ -x /usr/libexec/bluetooth/bt-ensure-agent.sh ]; then
	/usr/libexec/bluetooth/bt-ensure-agent.sh || log "pair agent failed (pairing may fail)"
elif [ -x /usr/libexec/bluetooth/bt-pair-agent.sh ]; then
	pkill -f '/usr/libexec/bluetooth/bt-pair-agent.sh' 2>/dev/null || true
	/usr/libexec/bluetooth/bt-pair-agent.sh >/tmp/lws-bt-agent.log 2>&1 &
	log "pair agent started (legacy)"
fi

# Ensure Classic page/inquiry scan after power-on (bredr speaker mode).
if command -v bluetoothctl >/dev/null 2>&1; then
	bluetoothctl pairable on >/dev/null 2>&1 || true
fi
if command -v hciconfig >/dev/null 2>&1; then
	hciconfig hci0 piscan >/dev/null 2>&1 || true
	hciconfig hci0 sspmode 1 >/dev/null 2>&1 || true
fi

# A2DP Sink is opt-in (Demo switch / bt-a2dp-sink-up.sh). Default: leave off.
# HOGP/evdev attach is in-HAL when Connected (cyber_hal); link reconnect is BlueZ Policy.
# If preference file was previously set to 1, restore speaker mode after stack up.
PREF="${LWS_BT_A2DP_PREF:-/var/lib/bluetooth/bt-a2dp-sink}"
if [ -f "$PREF" ] && [ "$(tr -d '[:space:]' <"$PREF" 2>/dev/null || true)" = "1" ]; then
	if [ -x /usr/libexec/bluetooth/bt-a2dp-sink-up.sh ]; then
		/usr/libexec/bluetooth/bt-a2dp-sink-up.sh || log "a2dp-sink restore soft-fail"
	fi
else
	log "a2dp-sink off (default; enable via Demo switch)"
fi

log "ok (alias=$ALIAS)"
