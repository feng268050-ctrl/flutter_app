#!/bin/sh
# Prepare storage for immediate poweroff without stopping flutter-pi.
set -u

log() {
	msg="lws-hmi-pre-poweroff: $*"
	echo "$msg"
	echo "$msg" >/dev/console 2>/dev/null || true
}

sync
sleep 0.2
sync
log "storage synced; ready for immediate poweroff"
