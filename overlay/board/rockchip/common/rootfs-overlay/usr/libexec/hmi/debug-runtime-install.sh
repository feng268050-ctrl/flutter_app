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

rm -rf "$DEST"
mkdir -p "$DEST"
# Rename (not cp) so peak free space ≈ one engine copy — needed on tight emulator rootfs.
mv "$STAGE/manifest.json" "$DEST/manifest.json"
mv "$STAGE/libflutter_engine.so" "$DEST/libflutter_engine.so"
mv "$STAGE/icudtl.dat" "$DEST/icudtl.dat"
sync
rm -rf "$STAGE"
log "installed debug runtime at $DEST"
