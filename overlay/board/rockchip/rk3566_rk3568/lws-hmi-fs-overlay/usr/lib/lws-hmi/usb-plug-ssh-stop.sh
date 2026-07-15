#!/bin/sh
# Stop usb0-only sshd and release the g_ether gadget module.
set -eu

SSHD_PID=/run/lws-hmi-usb-plug-sshd.pid

log() {
	echo "usb-plug-ssh-stop: $*"
}

if [ -f "$SSHD_PID" ]; then
	pid="$(cat "$SSHD_PID" 2>/dev/null || true)"
	[ -z "$pid" ] || kill "$pid" 2>/dev/null || true
	rm -f "$SSHD_PID"
fi

if [ -d /sys/class/net/usb0 ]; then
	ip addr flush dev usb0 2>/dev/null || true
	ip link set usb0 down 2>/dev/null || true
fi

# Soft-disconnect before rmmod so the host drops the gadget cleanly.
for udc in /sys/class/udc/*; do
	[ -e "$udc" ] || continue
	sf="$udc/soft_connect"
	[ -w "$sf" ] || continue
	printf '%s\n' disconnect >"$sf" 2>/dev/null || echo 0 >"$sf" 2>/dev/null || true
done
sleep 0.2

if [ -d /sys/module/g_ether ]; then
	if modprobe -r g_ether 2>/dev/null || rmmod g_ether 2>/dev/null; then
		log "g_ether unloaded"
	else
		# Do not exit 1: RemainAfterExit oneshot must become inactive so the
		# next VBUS attach still runs ExecStart (which force-reloads).
		log "WARN: could not unload g_ether (start will force-reload)"
	fi
fi
