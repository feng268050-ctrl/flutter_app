#!/bin/sh
# P1 debug: bring up RJ45 + USB ECM, static + link-local, start sshd.
set -u

LOG=/run/lws-hmi-debug.log
log() { echo "lws-hmi-debug-boot: $*" | tee -a "$LOG"; }

setup_usb_ecm() {
	[ -d /sys/class/udc ] || return 0
	if ip link show usb0 >/dev/null 2>&1; then
		return 0
	fi
	modprobe libcomposite 2>/dev/null || true
	modprobe usb_f_ecm 2>/dev/null || true
	modprobe g_ether 2>/dev/null || true
	sleep 1
}

bring_up_iface() {
	local ifc="$1"
	[ -d "/sys/class/net/$ifc" ] || return 1
	ip link set "$ifc" up 2>/dev/null || true
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		if grep -q "1" "/sys/class/net/$ifc/carrier" 2>/dev/null; then
			break
		fi
		sleep 0.5
	done
	ip addr add "10.0.0.240/24" dev "$ifc" 2>/dev/null || true
	ip addr add "169.254.10.1/16" dev "$ifc" 2>/dev/null || true
	log "$ifc up addrs 10.0.0.240/24 + 169.254.10.1/16 carrier=$(cat /sys/class/net/$ifc/carrier 2>/dev/null || echo ?)"
	return 0
}

: >"$LOG"
setup_usb_ecm
for ifc in usb0 eth0 end0; do
	bring_up_iface "$ifc" || true
done

ip -4 addr show >>"$LOG" 2>&1 || true
ip link show >>"$LOG" 2>&1 || true

if command -v systemctl >/dev/null 2>&1; then
	systemctl start sshd.service 2>/dev/null || systemctl start sshd 2>/dev/null || true
fi

log "Mac RJ45: bash scripts/mac-debug-net.sh  then ping/ssh 10.0.0.240"
log "Mac USB: if usb0 appears, ping 169.254.10.1"
log "done"
