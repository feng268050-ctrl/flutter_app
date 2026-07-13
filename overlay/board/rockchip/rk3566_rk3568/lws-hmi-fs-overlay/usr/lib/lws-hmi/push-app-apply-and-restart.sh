#!/bin/sh
# Apply make push-app staging payload and restart flutter-pi in place.
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
[ -d "$ASSETS" ] || {
	log "missing $ASSETS"
	exit 1
}

log "stopping hmi.service"
systemctl stop hmi.service

log "installing libapp.so and flutter_assets"
install -D -m 0644 "$LIB" /opt/hmi/lib/libapp.so
rm -rf /opt/hmi/data/flutter_assets
mkdir -p /opt/hmi/data/flutter_assets
cp -a "$ASSETS/." /opt/hmi/data/flutter_assets/
sync

log "starting hmi.service"
systemctl reset-failed hmi.service
systemctl start hmi.service
systemctl is-active --quiet hmi.service
log "restart complete"
