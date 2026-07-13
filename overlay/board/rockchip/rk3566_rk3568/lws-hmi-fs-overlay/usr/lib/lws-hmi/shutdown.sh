#!/bin/sh
# Avoid flutter-pi teardown during shutdown; use crash-safe SysRq first.
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
	msg="lws-hmi-shutdown: $*"
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

if [ ! -x /usr/bin/systemctl.real ]; then
	log "missing /usr/bin/systemctl.real"
	exit 1
fi

log "skipping hmi.service teardown; using SysRq $mode"
/usr/lib/lws-hmi/pre-poweroff.sh

log "sysrq sync"
sysrq s || true
sleep 0.5
log "sysrq remount-readonly"
sysrq u || true
sleep 0.5

case "$mode" in
poweroff|halt)
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
