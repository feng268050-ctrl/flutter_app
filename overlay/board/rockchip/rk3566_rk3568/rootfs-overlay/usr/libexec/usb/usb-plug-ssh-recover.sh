#!/bin/sh
# Recover g_ether USB plug-ssh without resetting the DWC3 controller.
set -eu

log() {
	echo "usb-plug-ssh-recover: $*"
}

log "stopping current g_ether session"
/usr/libexec/usb/usb-plug-ssh-stop.sh 2>/dev/null || true
sleep 1

if [ -d /sys/module/g_ether ]; then
	log "g_ether still loaded; refusing to compete for the UDC"
	exit 1
fi

log "starting a fresh g_ether session"
exec /usr/libexec/usb/usb-plug-ssh-start.sh
