#!/bin/sh
# Atomically replace /opt/hmi with staged debug payload (no automatic restore).
# Uses rename (mv) instead of cp so peak free space ≈ one payload, not two —
# critical on the P3.2 emulator (single 600M→grown rootfs, no userdata bind).
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

log "stopping current HMI"
/usr/libexec/hmi/hmi-stop-and-wait.sh

# Drop failed / leftover trees before rename.
rm -rf "$NEXT" "$DEST"
# Same filesystem: rename staging → /opt/hmi (no 2× copy).
mv "$STAGE" "$DEST"
sync
log "installed debug payload at $DEST"
