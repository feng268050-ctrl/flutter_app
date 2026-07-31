#!/bin/sh
# Flush storage before immediate SysRq shutdown.
set -u

log() {
	msg="pre-poweroff: $*"
	echo "$msg"
	echo "$msg" >/dev/console 2>/dev/null || true
}

sync
sleep 0.2
sync

# Persist wall clock to external RTC before SysRq (ynh960: pcf8563 as rtc0).
if [ -x /usr/sbin/hwclock ]; then
	/usr/sbin/hwclock -w -u -f /dev/rtc0 >/dev/console 2>&1 || true
elif [ -x /sbin/hwclock ]; then
	/sbin/hwclock -w -u -f /dev/rtc0 >/dev/console 2>&1 || true
fi

log "storage synced; ready for shutdown"
