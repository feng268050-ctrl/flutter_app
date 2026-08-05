#!/bin/sh
# On-demand LAN/WLAN SSH debug (P2.1 / §7.7). Not enabled at boot.
# Starts ssh-debug-lan.service (eth0/wlan0 only) without stopping USB-SSH.
# Usage: enable-ssh-debug.sh [enable|disable|status|on|off]
set -eu

UNIT=ssh-debug-lan.service
USB_PID=/run/usb-plug-sshd.pid

log() {
	echo "enable-ssh-debug: $*"
}

lan_running() {
	systemctl is-active --quiet "$UNIT" 2>/dev/null
}

usb_sshd_running() {
	[ -f "$USB_PID" ] && kill -0 "$(cat "$USB_PID")" 2>/dev/null
}

has_lan_ipv4() {
	for iface in eth0 wlan0; do
		[ -d "/sys/class/net/$iface" ] || continue
		if ip -4 -o addr show dev "$iface" scope global 2>/dev/null | grep -q .; then
			return 0
		fi
	done
	return 1
}

cmd_status() {
	if lan_running; then
		echo "enabled"
		return 0
	fi
	echo "disabled"
	return 1
}

cmd_enable() {
	if lan_running; then
		log "already enabled"
		return 0
	fi
	if ! has_lan_ipv4; then
		log "ERROR: no eth0/wlan0 IPv4 — enable Ethernet/Wi-Fi and get an address first"
		return 1
	fi
	# Do NOT stop USB plug-ssh: LAN binds eth0/wlan0 only; USB keeps 192.168.55.1.
	/usr/libexec/ssh/ensure-sshd-hostkeys.sh
	systemctl reset-failed "$UNIT" 2>/dev/null || true
	systemctl start "$UNIT"
	i=0
	while [ "$i" -lt 50 ]; do
		if lan_running; then
			log "enabled ($UNIT active; USB-SSH on 192.168.55.1 unaffected)"
			return 0
		fi
		if systemctl is-failed --quiet "$UNIT" 2>/dev/null; then
			log "ERROR: $UNIT failed to start"
			systemctl status "$UNIT" --no-pager -l 2>/dev/null || true
			return 1
		fi
		i=$((i + 1))
		sleep 0.1
	done
	log "ERROR: timed out waiting for $UNIT"
	systemctl status "$UNIT" --no-pager -l 2>/dev/null || true
	return 1
}

ensure_usb_sshd_if_needed() {
	[ -d /sys/class/net/usb0 ] || return 0
	usb_sshd_running && return 0
	if [ -x /usr/libexec/usb/usb-plug-ssh-start.sh ]; then
		/usr/libexec/usb/usb-plug-ssh-start.sh || true
	fi
}

cmd_disable() {
	systemctl reset-failed "$UNIT" 2>/dev/null || true
	systemctl stop "$UNIT" 2>/dev/null || true
	log "disabled"
	rm -f /run/lan-sshd.pid
	ensure_usb_sshd_if_needed
}

cmd="${1:-enable}"
case "$cmd" in
enable | on | start)
	cmd_enable
	;;
disable | off | stop)
	cmd_disable
	;;
status)
	cmd_status
	;;
-h | --help)
	echo "Usage: $0 [enable|disable|status]"
	;;
*)
	echo "Usage: $0 [enable|disable|status]" >&2
	exit 2
	;;
esac
