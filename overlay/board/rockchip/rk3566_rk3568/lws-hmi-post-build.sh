#!/bin/sh
# Run on Buildroot staging target/ before rootfs images are packed (BR2_ROOTFS_POST_BUILD_SCRIPT).
# sshd is disabled at boot — host keys must be baked in at build time.
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"

ensure_script="$TARGET_DIR/usr/lib/lws-hmi/ensure-sshd-hostkeys.sh"
if [ ! -f "$ensure_script" ]; then
	ensure_script="$LWS_HMI_ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi/ensure-sshd-hostkeys.sh"
fi

if [ ! -f "$ensure_script" ]; then
	echo "lws-hmi-post-build: ensure-sshd-hostkeys.sh missing" >&2
	exit 1
fi

sh "$ensure_script" "$TARGET_DIR"

SYNC_ENGINE="$(dirname "$0")/lws-hmi-sync-flutter-engine.sh"
if [ -f "$SYNC_ENGINE" ]; then
	sh "$SYNC_ENGINE" "$TARGET_DIR"
fi

# App bundle must not ship engine/icu (system paths only).
rm -f \
	"$TARGET_DIR/opt/hmi/lib/libflutter_engine.so" \
	"$TARGET_DIR/opt/hmi/data/icudtl.dat"
