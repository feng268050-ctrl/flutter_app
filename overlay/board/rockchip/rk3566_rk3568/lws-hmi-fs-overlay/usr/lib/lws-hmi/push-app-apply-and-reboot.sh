#!/bin/sh
# Apply make push-app staging payload, then sysrq reboot (no systemctl stop hmi).
set -eu

STAGE=/var/lib/lws-hmi/push-app-staging
LIB="$STAGE/lib/libapp.so"
ASSETS="$STAGE/data/flutter_assets"

log() {
	echo "lws-hmi-push-app: $*"
}

[ -f "$LIB" ] || {
	log "missing $LIB"
	exit 1
}

log "install libapp.so"
install -D -m 0644 "$LIB" /opt/hmi/lib/libapp.so

if [ -d "$ASSETS" ]; then
	log "install flutter_assets"
	mkdir -p /opt/hmi/data/flutter_assets
	cp -a "$ASSETS/." /opt/hmi/data/flutter_assets/
fi

sync
log "reboot scheduled (sysrq via shutdown.sh — skip Mali teardown)"
( sleep 2; /usr/lib/lws-hmi/shutdown.sh reboot ) >/dev/console 2>&1 &
exit 0
