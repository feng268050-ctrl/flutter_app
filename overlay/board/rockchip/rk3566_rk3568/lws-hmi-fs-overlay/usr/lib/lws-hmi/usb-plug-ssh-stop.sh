#!/bin/sh
# Tear down USB ECM gadget and stop usb0-only sshd.
set -eu

GADGET=/sys/kernel/config/usb_gadget/lws_hmi
SSHD_PID=/run/lws-hmi-usb-plug-sshd.pid

log() {
	echo "usb-plug-ssh-stop: $*"
}

if [ -f "$SSHD_PID" ]; then
	pid="$(cat "$SSHD_PID" 2>/dev/null || true)"
	if [ -n "$pid" ]; then
		kill "$pid" 2>/dev/null || true
	fi
	rm -f "$SSHD_PID"
fi

if [ -d "$GADGET" ]; then
	bound="$(cat "$GADGET/UDC" 2>/dev/null || true)"
	if [ -n "$bound" ]; then
		sf="/sys/class/udc/$bound/soft_connect"
		[ -w "$sf" ] && { printf '%s\n' disconnect >"$sf" 2>/dev/null || echo 0 >"$sf" 2>/dev/null || true; }
		sleep 0.2
	fi
	if ! echo "" >"$GADGET/UDC" 2>/dev/null; then
		log "WARN: UDC unbind failed (may stay configured until cable replug)"
	fi
	sleep 0.3
	rm -f "$GADGET/configs/c.1/ecm.usb0" 2>/dev/null || true
	rmdir "$GADGET/functions/ecm.usb0" 2>/dev/null || true
	rmdir "$GADGET/configs/c.1/strings/0x409" 2>/dev/null || true
	rmdir "$GADGET/configs/c.1" 2>/dev/null || true
	rmdir "$GADGET/strings/0x409" 2>/dev/null || true
	rmdir "$GADGET" 2>/dev/null || true
	log "gadget removed"
fi

ip link set usb0 down 2>/dev/null || true
ip addr flush dev usb0 2>/dev/null || true
