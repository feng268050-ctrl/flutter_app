#!/bin/sh
# Hard reset USB DRD path for plug-ssh when configfs UDC bind returns EBUSY.
set -u

GADGET=/sys/kernel/config/usb_gadget/lws_hmi
DWC3_GADGET=fcc00000.usb
DWC3_HOST=fd000000.usb
DRV=/sys/bus/platform/drivers/dwc3

log() {
	echo "usb-plug-ssh-recover: $*"
}

log_warn() {
	echo "usb-plug-ssh-recover: WARN: $*" >&2
}

stop_gadget() {
	if [ -x /usr/lib/lws-hmi/usb-plug-ssh-stop.sh ]; then
		/usr/lib/lws-hmi/usb-plug-ssh-stop.sh 2>/dev/null || true
	fi
	if [ -d "$GADGET" ]; then
		bound="$(cat "$GADGET/UDC" 2>/dev/null || true)"
		if [ -n "$bound" ]; then
			printf '%s\n' disconnect >"/sys/class/udc/$bound/soft_connect" 2>/dev/null \
				|| echo 0 >"/sys/class/udc/$bound/soft_connect" 2>/dev/null || true
			echo "" >"$GADGET/UDC" 2>/dev/null || true
		fi
		rm -f "$GADGET/configs/c.1/ecm.usb0" 2>/dev/null || true
		rmdir "$GADGET/functions/ecm.usb0" 2>/dev/null || true
		rmdir "$GADGET/configs/c.1/strings/0x409" 2>/dev/null || true
		rmdir "$GADGET/configs/c.1" 2>/dev/null || true
		rmdir "$GADGET/strings/0x409" 2>/dev/null || true
		rmdir "$GADGET" 2>/dev/null || true
	fi
}

unbind_configfs_gadgets() {
	local g
	[ -d /sys/kernel/config/usb_gadget ] || return 0
	for g in /sys/kernel/config/usb_gadget/*; do
		[ -f "$g/UDC" ] || continue
		echo "" >"$g/UDC" 2>/dev/null || true
	done
}

release_dwc3_host() {
	[ -d "$DRV" ] || return 0
	if [ -e "$DRV/$DWC3_HOST" ]; then
		echo "$DWC3_HOST" >"$DRV/unbind" 2>/dev/null && \
			log "unbound $DWC3_HOST" || log_warn "unbind $DWC3_HOST failed"
	fi
}

set_otg_peripheral() {
	local f
	for f in /sys/devices/platform/fe8a0000.usb2-phy/otg_mode \
		/sys/devices/platform/*/fe8a0000.*/otg_mode; do
		[ -w "$f" ] || continue
		echo peripheral >"$f" 2>/dev/null || true
	done
	for f in /sys/class/usb_role/*/role; do
		[ -w "$f" ] || continue
		case "$(readlink -f "$(dirname "$f")" 2>/dev/null || true)" in
		*fe8a0000*)
			echo device >"$f" 2>/dev/null || echo peripheral >"$f" 2>/dev/null || true
			;;
		esac
	done
}

reset_dwc3_gadget() {
	[ -d "$DRV" ] || return 0
	if [ -e "$DRV/$DWC3_GADGET" ]; then
		echo "$DWC3_GADGET" >"$DRV/unbind" 2>/dev/null && \
			log "unbound $DWC3_GADGET" || log_warn "unbind $DWC3_GADGET failed"
		sleep 1
	fi
	if [ ! -e "$DRV/$DWC3_GADGET" ]; then
		echo "$DWC3_GADGET" >"$DRV/bind" 2>/dev/null && \
			log "bound $DWC3_GADGET" || log_warn "bind $DWC3_GADGET failed"
		sleep 1
	fi
}

show_diag() {
	log "diag: udc state=$(cat /sys/class/udc/$DWC3_GADGET/state 2>/dev/null || echo missing)"
	log "diag: dwc3=$(ls "$DRV" 2>/dev/null || echo missing)"
	log "diag: gadgets=$(ls /sys/kernel/config/usb_gadget 2>/dev/null || echo none)"
	log "diag: usb0=$(ip -br link show usb0 2>/dev/null || echo missing)"
	if [ -e "/sys/class/udc/$DWC3_GADGET/gadget" ]; then
		log "diag: kernel gadget=$(cat "/sys/class/udc/$DWC3_GADGET/gadget" 2>/dev/null || echo ?)"
	fi
}

log "starting USB DRD recovery"
stop_gadget
unbind_configfs_gadgets
release_dwc3_host
set_otg_peripheral
reset_dwc3_gadget
show_diag
log "done — run /usr/lib/lws-hmi/usb-plug-ssh-start.sh"
