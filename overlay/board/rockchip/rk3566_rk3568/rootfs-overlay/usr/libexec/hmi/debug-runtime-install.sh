#!/bin/sh
# Install cached debug engine + ICU under /var/lib/hmi/debug-runtime/<version>/.
set -eu

STAGE=/var/lib/hmi/debug-runtime-staging
DEST_ROOT=/var/lib/hmi/debug-runtime

log() {
	echo "debug-runtime: $*"
}

[ -f "$STAGE/manifest.json" ] || {
	log "missing $STAGE/manifest.json"
	exit 1
}
[ -f "$STAGE/libflutter_engine.so" ] || {
	log "missing $STAGE/libflutter_engine.so"
	exit 1
}
[ -f "$STAGE/icudtl.dat" ] || {
	log "missing $STAGE/icudtl.dat"
	exit 1
}

VER="$(grep -o '"engine_version"[[:space:]]*:[[:space:]]*"[^"]*"' "$STAGE/manifest.json" \
	| sed 's/.*"\([^"]*\)"$/\1/' | head -1)"
[ -n "$VER" ] || {
	log "manifest missing engine_version"
	exit 1
}

DEST="$DEST_ROOT/$VER"
if [ -f "$DEST/manifest.json" ] && cmp -s "$STAGE/manifest.json" "$DEST/manifest.json"; then
	log "runtime already cached at $DEST"
	rm -rf "$STAGE"
	exit 0
fi

mkdir -p "$DEST"
cp -f "$STAGE/manifest.json" "$DEST/manifest.json"
cp -f "$STAGE/libflutter_engine.so" "$DEST/libflutter_engine.so"
cp -f "$STAGE/icudtl.dat" "$DEST/icudtl.dat"
sync
rm -rf "$STAGE"
log "installed debug runtime at $DEST"
