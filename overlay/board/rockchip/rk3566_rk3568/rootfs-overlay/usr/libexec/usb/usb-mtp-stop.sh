#!/bin/sh
# Stop USB MTP responder and tear down FunctionFS/configfs gadget.
set -eu

. /usr/libexec/board/paths.sh 2>/dev/null || true

PIDFILE="${RUN_USB_MTP_PID:-/run/usb-mtp.pid}"
GADGET_ROOT="${USB_MTP_GADGET_ROOT:-/sys/kernel/config/usb_gadget/lws-mtp}"
FFS_MOUNT="${USB_MTP_FFS_MOUNT:-/dev/ffs-mtp}"
RUN_FLAG="${RUN_USB_MTP_ACTIVE:-/run/usb-mtp.active}"

log() {
	echo "usb-mtp-stop: $*"
}

if systemctl is-active --quiet usb-mtp.service 2>/dev/null; then
	systemctl stop usb-mtp.service 2>/dev/null || true
fi

if [ -f "$PIDFILE" ]; then
	pid="$(cat "$PIDFILE" 2>/dev/null || true)"
	if [ -n "$pid" ]; then
		kill "$pid" 2>/dev/null || true
		i=0
		while [ "$i" -lt 20 ] && kill -0 "$pid" 2>/dev/null; do
			sleep 0.1
			i=$((i + 1))
		done
		kill -9 "$pid" 2>/dev/null || true
	fi
	rm -f "$PIDFILE"
fi

if [ -d "$GADGET_ROOT" ]; then
	echo "" >"$GADGET_ROOT/UDC" 2>/dev/null || true
	rm -f "$GADGET_ROOT/configs/c.1/ffs.mtp" 2>/dev/null || true
	rmdir "$GADGET_ROOT/functions/ffs.mtp" 2>/dev/null || true
	rmdir "$GADGET_ROOT/configs/c.1/strings/0x409" 2>/dev/null || true
	rmdir "$GADGET_ROOT/configs/c.1" 2>/dev/null || true
	rmdir "$GADGET_ROOT/strings/0x409" 2>/dev/null || true
	rmdir "$GADGET_ROOT" 2>/dev/null || true
fi

if grep -q " ${FFS_MOUNT} " /proc/mounts 2>/dev/null; then
	umount "$FFS_MOUNT" 2>/dev/null || true
fi
rmdir "$FFS_MOUNT" 2>/dev/null || true

rm -f "$RUN_FLAG"
modprobe -r g_ffs 2>/dev/null || true
log "stopped"
exit 0
