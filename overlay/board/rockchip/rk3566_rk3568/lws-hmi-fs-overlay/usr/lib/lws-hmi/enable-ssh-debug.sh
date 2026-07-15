#!/bin/sh
# On-demand LAN/WLAN SSH debug (P2.1 / §7.7). Not enabled at boot.
# Usage: enable-ssh-debug.sh [enable|disable|status|on|off]
set -eu

LAN_PID=/run/lws-hmi-lan-sshd.pid
USB_PID=/run/lws-hmi-usb-plug-sshd.pid

log() {
	echo "enable-ssh-debug: $*"
}

lan_running() {
	[ -f "$LAN_PID" ] && kill -0 "$(cat "$LAN_PID")" 2>/dev/null
}

usb_sshd_running() {
	[ -f "$USB_PID" ] && kill -0 "$(cat "$USB_PID")" 2>/dev/null
}

port22_listening() {
	if command -v ss >/dev/null 2>&1; then
		ss -lntp 2>/dev/null | grep -qE '(:|\])22\s'
		return $?
	fi
	if command -v netstat >/dev/null 2>&1; then
		netstat -lntp 2>/dev/null | grep -qE '(:|\])22\s'
		return $?
	fi
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
		log "already enabled (pid=$(cat "$LAN_PID"))"
		return 0
	fi
	/usr/lib/lws-hmi/ensure-sshd-hostkeys.sh
	mkdir -p /run/sshd
	chmod 0755 /run/sshd 2>/dev/null || true
	# If only USB-dedicated sshd is up, stop it so we can bind *:22 (covers usb0 too).
	if usb_sshd_running; then
		log "stopping USB-only sshd so LAN listener can bind *:22"
		kill "$(cat "$USB_PID")" 2>/dev/null || true
		rm -f "$USB_PID"
		sleep 0.3
	fi
	/usr/sbin/sshd \
		-f /etc/ssh/sshd_config \
		-o "ListenAddress=0.0.0.0" \
		-o "PasswordAuthentication=yes" \
		-o "PermitRootLogin=yes" \
		-o "PidFile=$LAN_PID"
	# Wait briefly for listen.
	i=0
	while [ "$i" -lt 20 ]; do
		lan_running && port22_listening && break
		i=$((i + 1))
		sleep 0.1
	done
	if ! lan_running; then
		log "ERROR: failed to start LAN sshd"
		return 1
	fi
	log "enabled (LAN/WLAN sshd pid=$(cat "$LAN_PID"))"
}

ensure_usb_sshd_if_needed() {
	[ -d /sys/class/net/usb0 ] || return 0
	usb_sshd_running && return 0
	lan_running && return 0
	if [ -x /usr/lib/lws-hmi/usb-plug-ssh-start.sh ]; then
		# Re-run start: g_ether may already be loaded; script is idempotent for that.
		/usr/lib/lws-hmi/usb-plug-ssh-start.sh || true
	fi
}

cmd_disable() {
	if lan_running; then
		kill "$(cat "$LAN_PID")" 2>/dev/null || true
		rm -f "$LAN_PID"
		log "disabled"
	else
		rm -f "$LAN_PID"
		log "already disabled"
	fi
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
