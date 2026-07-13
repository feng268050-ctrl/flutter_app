#!/bin/sh
# Apply make push-app staging payload while HMI runs, then restart it.
set -eu

STAGE=/var/lib/lws-hmi/push-app-staging
LIB="$STAGE/lib/libapp.so"
ASSETS="$STAGE/data/flutter_assets"
NEXT_LIB=/opt/hmi/lib/.libapp.so.push-next
ASSETS_DIR=/opt/hmi/data/flutter_assets
NEXT_ASSETS=/opt/hmi/data/.flutter_assets.push-next
OLD_ASSETS=/opt/hmi/data/.flutter_assets.push-old
MAX_START_ATTEMPTS=3

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

log "installing libapp.so and flutter_assets before restart"
rm -rf "$NEXT_LIB" "$NEXT_ASSETS" "$OLD_ASSETS"
install -D -m 0644 "$LIB" "$NEXT_LIB"
mkdir -p "$NEXT_ASSETS"
cp -a "$ASSETS/." "$NEXT_ASSETS/"
sync

mv -f "$NEXT_LIB" /opt/hmi/lib/libapp.so
if [ -d "$ASSETS_DIR" ]; then
	mv "$ASSETS_DIR" "$OLD_ASSETS"
fi
if ! mv "$NEXT_ASSETS" "$ASSETS_DIR"; then
	[ ! -d "$OLD_ASSETS" ] || mv "$OLD_ASSETS" "$ASSETS_DIR"
	log "failed to activate flutter_assets"
	exit 1
fi
rm -rf "$OLD_ASSETS"
sync

attempt=1
while [ "$attempt" -le "$MAX_START_ATTEMPTS" ]; do
	log "restart attempt $attempt/$MAX_START_ATTEMPTS"
	systemctl reset-failed hmi.service
	if [ "$attempt" -eq 1 ]; then
		systemctl restart hmi.service || true
	else
		systemctl start hmi.service || true
	fi
	sleep 1
	if systemctl is-active --quiet hmi.service && pidof flutter-pi >/dev/null 2>&1; then
		log "restart complete"
		exit 0
	fi
	attempt=$((attempt + 1))
done

log "hmi.service did not recover after $MAX_START_ATTEMPTS attempts"
systemctl status hmi.service --no-pager -l || true
exit 1
