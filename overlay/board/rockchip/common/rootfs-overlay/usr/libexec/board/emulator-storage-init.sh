#!/bin/sh
# Emulator early storage: provision mount + userdata prefs bind (storage-init is skipped).
set -eu

log() {
	echo "emulator-storage-init: $*"
}

mkdir -p /userdata /oem

if [ -x /usr/libexec/board/provision-mount.sh ]; then
	/usr/libexec/board/provision-mount.sh || log "provision-mount soft-fail"
fi

if [ -x /usr/libexec/board/bind-prefs.sh ]; then
	/usr/libexec/board/bind-prefs.sh || log "bind-prefs soft-fail"
fi

if [ -x /usr/libexec/board/apply-datetime-prefs.sh ]; then
	/usr/libexec/board/apply-datetime-prefs.sh || log "apply-datetime-prefs soft-fail"
fi

log "done"
exit 0
