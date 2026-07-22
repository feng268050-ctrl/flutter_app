#!/bin/sh
# Tune eth0 for IPC RTSP (100M RMII dedicated link).
# Hygiene only — root cause of Linux vs Android bitrate gap was RMII
# clock_in_out (see docs/ip-camera-rtsp-bitrate-android-vs-linux.md).
# - stmmac: flow_ctrl=0, watchdog=0 (default flow_ctrl=3 + RIWT 5ms was a
#   secondary throttle under the wrong clock; still useful on this path)
# - Raise UDP socket ceilings + RPS
#
# IMPORTANT: do NOT call ethtool -G / resize DMA rings here.
# Ring resize downs eth0 and, with HMI/networkd, caused tens–hundreds of
# Link Up/Down events and destroyed RTSP.
#
# KEEP: call after networkd has brought the link up (apply-eth0.sh).
# Bootargs may also set stmmac.* for probe.
set -eu

IFACE="${1:-${LWS_ETH_IFACE:-eth0}}"

log() {
	echo "eth0-tune: $*" >&2
}

case "$IFACE" in
wlan0|usb0|lo)
	log "refusing $IFACE"
	exit 1
	;;
esac

if [ ! -d "/sys/class/net/$IFACE" ]; then
	log "$IFACE missing"
	exit 1
fi

# stmmac built-in defaults (flow_ctrl=3, watchdog=5000) throttle IPC RTSP on
# this RMII path. Sysfs only — no ndo_stop / ring recreate.
STMMAC_P=/sys/module/stmmac/parameters
if [ -d "$STMMAC_P" ]; then
	[ -w "$STMMAC_P/flow_ctrl" ] && echo 0 >"$STMMAC_P/flow_ctrl" || true
	[ -w "$STMMAC_P/pause" ] && echo 0 >"$STMMAC_P/pause" || true
	[ -w "$STMMAC_P/watchdog" ] && echo 0 >"$STMMAC_P/watchdog" || true
	[ -w "$STMMAC_P/eee_timer" ] && echo 0 >"$STMMAC_P/eee_timer" || true
	log "stmmac flow_ctrl=$(cat "$STMMAC_P/flow_ctrl" 2>/dev/null) watchdog=$(cat "$STMMAC_P/watchdog" 2>/dev/null)"
fi

sysctl -w net.core.rmem_max=26214400 >/dev/null 2>&1 || true
sysctl -w net.core.rmem_default=4194304 >/dev/null 2>&1 || true
sysctl -w net.core.wmem_max=26214400 >/dev/null 2>&1 || true
sysctl -w net.core.netdev_max_backlog=5000 >/dev/null 2>&1 || true

if [ -w "/sys/class/net/$IFACE/queues/rx-0/rps_cpus" ]; then
	echo f >"/sys/class/net/$IFACE/queues/rx-0/rps_cpus" 2>/dev/null || true
fi
sysctl -w net.core.rps_sock_flow_entries=32768 >/dev/null 2>&1 || true

# Pause autoneg can leave "RX/TX negotiated: on" even when local rx/tx are
# off — ethtool -A only (no ring resize; ring ops flap this SoC).
if command -v ethtool >/dev/null 2>&1; then
	ethtool -A "$IFACE" autoneg off rx off tx off 2>/dev/null || true
fi

log "ok on $IFACE (sysfs/sysctl only; no ring resize)"
