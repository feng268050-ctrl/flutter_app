#!/bin/sh
# Avoid DRM/Mali teardown oops by powering off without stopping user services.
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

/usr/lib/lws-hmi/pre-poweroff.sh

case "$mode" in
poweroff|halt)
	log "sysrq sync"
	sysrq s || true
	sleep 0.5
	log "sysrq remount-readonly"
	sysrq u || true
	sleep 0.5
	log "sysrq poweroff"
	if sysrq o; then
		sleep 5
	fi
	;;
reboot)
	log "sysrq sync"
	sysrq s || true
	sleep 0.5
	log "sysrq remount-readonly"
	sysrq u || true
	sleep 0.5
	log "sysrq reboot"
	if sysrq b; then
		# Board should reset immediately; do not fall through to systemctl stop.
		sleep 15
		log "sysrq reboot did not reset"
	fi
	;;
esac

if [ "$mode" = reboot ]; then
	if [ -x /sbin/reboot ]; then
		log "fallback: /sbin/reboot -f"
		exec /sbin/reboot -f
	fi
fi

if [ ! -x /usr/bin/systemctl.real ]; then
	log "missing /usr/bin/systemctl.real"
	exit 1
fi

exec /usr/bin/systemctl.real --force --force --no-ask-password "$mode" "$@"
