#!/bin/sh
# Atomically replace /opt/hmi with staged debug payload (no automatic restore).
set -eu

STAGE=/var/lib/hmi/debug-app-staging
DEST=/opt/hmi
NEXT=/opt/hmi.debug-next
KERNEL="$STAGE/data/flutter_assets/kernel_blob.bin"
MODE_FILE="$STAGE/runtime-mode.json"

log() {
	echo "debug-app: $*"
}

[ -f "$KERNEL" ] || {
	log "missing $KERNEL"
	exit 1
}
[ -f "$MODE_FILE" ] || {
	log "missing $MODE_FILE"
	exit 1
}

# Defense in depth: host deploy should refuse Weston first; never blank the panel.
stack=flutter-pi
if [ -f /etc/display-stack ]; then
	stack="$(tr -d '[:space:]' </etc/display-stack | tr '[:upper:]' '[:lower:]')"
elif [ -f /etc/hmi/display-stack ]; then
	stack="$(tr -d '[:space:]' </etc/hmi/display-stack | tr '[:upper:]' '[:lower:]')"
fi
case "$stack" in
weston | wayland | elinux)
	log "refusing debug install on display-stack=$stack (needs AOT libapp.so)"
	log "restore with: make build-app && make push-app"
	rm -rf "$STAGE"
	exit 1
	;;
esac

log "stopping current HMI"
/usr/libexec/hmi/hmi-stop-and-wait.sh

rm -rf "$NEXT"
mkdir -p "$NEXT/data"
cp -a "$STAGE/." "$NEXT/"
sync
rm -rf "$DEST"
mv "$NEXT" "$DEST"
sync
rm -rf "$STAGE"
log "installed debug payload at $DEST"
