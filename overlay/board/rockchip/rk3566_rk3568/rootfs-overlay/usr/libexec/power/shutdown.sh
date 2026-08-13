#!/bin/sh
# Avoid HMI embedder teardown during shutdown; use crash-safe SysRq first.
set -eu

mode="${1:-poweroff}"
case "$mode" in
poweroff|halt|reboot) ;;
*)
	echo "usage: shutdown.sh poweroff|halt|reboot" >&2
	exit 1
	;;
esac

shift

log() {
	msg="shutdown: $*"
	echo "$msg"
	echo "$msg" >/dev/console 2>/dev/null || true
}

sysrq() {
	key="$1"
	if [ -w /proc/sysrq-trigger ]; then
		echo 1 >/proc/sys/kernel/sysrq 2>/dev/null || true
		echo "$key" >/proc/sysrq-trigger
		return 0
	fi
	return 1
}

# RK809/RK817 SYS_CFG3 bit0 = DEV_OFF. SysRq/PSCI alone can freeze the SoC
# while the PMIC stays ON (off=0x00), so PWRON cannot cold-boot until rails
# are hard-killed. Vendor rk8xx_device_shutdown() skips RK809/817.
rk809_dev_off() {
	if [ -w /sys/rk8xx/rk8xx_dbg ]; then
		echo w f4 01 >/sys/rk8xx/rk8xx_dbg 2>/dev/null || return 1
		return 0
	fi
	return 1
}

if [ ! -x /usr/bin/systemctl.real ]; then
	log "missing /usr/bin/systemctl.real"
	exit 1
fi

log "skipping hmi.service teardown; using SysRq $mode"
/usr/libexec/power/pre-poweroff.sh

log "sysrq sync"
sysrq s || true
sleep 0.5
log "sysrq remount-readonly"
sysrq u || true
sleep 0.5

case "$mode" in
poweroff|halt)
	log "rk809 DEV_OFF"
	rk809_dev_off || log "rk809 DEV_OFF unavailable; falling back to SysRq"
	log "sysrq poweroff"
	if sysrq o; then
		sleep 5
	fi
	;;
reboot)
	log "sysrq reboot"
	if sysrq b; then
		sleep 15
		log "sysrq reboot did not reset"
	fi
	if [ -x /sbin/reboot ]; then
		log "fallback: /sbin/reboot -f"
		exec /sbin/reboot -f
	fi
	;;
esac

exec /usr/bin/systemctl.real --force --force --no-ask-password "$mode" "$@"
