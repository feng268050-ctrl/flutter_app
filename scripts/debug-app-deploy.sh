#!/usr/bin/env bash
# Deploy debug app + runtime to the selected USB-SSH or registered SSH device.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/debug-runtime-common.sh
source "$ROOT/scripts/debug-runtime-common.sh"

STAGING="$(debug_runtime_staging_dir "$ROOT")"
DEVICE_APP_STAGE=/var/lib/lws-hmi/debug-app-staging
DEVICE_RUNTIME_STAGE=/var/lib/lws-hmi/debug-runtime-staging
RUNTIME_INSTALL=/usr/lib/lws-hmi/debug-runtime-install.sh
APP_APPLY=/usr/lib/lws-hmi/debug-app-apply.sh
ENGINE_VER="$(debug_runtime_engine_version "$ROOT")"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -d "$STAGING/opt/hmi/data/flutter_assets" ]] || die "missing debug staging (run: make build-debug-app)"

usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "debug-deploy: SSH target=$TARGET_USER@$TARGET_ADDR"
else
	echo "debug-deploy: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
fi

# Upload debug runtime when device cache is missing or manifest differs.
local_manifest="$STAGING/debug-runtime/$ENGINE_VER/manifest.json"
device_manifest_path="/var/lib/lws-hmi/debug-runtime/$ENGINE_VER/manifest.json"
need_runtime=1
if usb_ssh_session_run_ssh "$ROOT" "$IFACE" "test -f $device_manifest_path"; then
	if usb_ssh_session_run_ssh "$ROOT" "$IFACE" "cat $device_manifest_path" \
		| cmp -s - "$local_manifest"; then
		need_runtime=0
		echo "debug-deploy: runtime cache hit ($ENGINE_VER)"
	fi
fi

if [[ "$need_runtime" -eq 1 ]]; then
	echo "debug-deploy: uploading debug runtime $ENGINE_VER..."
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "rm -rf $DEVICE_RUNTIME_STAGE && mkdir -p $DEVICE_RUNTIME_STAGE"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"$STAGING/debug-runtime/$ENGINE_VER/manifest.json" \
		"$TARGET_USER@$TARGET_ADDR:$DEVICE_RUNTIME_STAGE/manifest.json"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"$STAGING/debug-runtime/$ENGINE_VER/libflutter_engine.so" \
		"$TARGET_USER@$TARGET_ADDR:$DEVICE_RUNTIME_STAGE/libflutter_engine.so"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"$STAGING/debug-runtime/$ENGINE_VER/icudtl.dat" \
		"$TARGET_USER@$TARGET_ADDR:$DEVICE_RUNTIME_STAGE/icudtl.dat"
	if ! usb_ssh_session_run_ssh "$ROOT" "$IFACE" "test -x $RUNTIME_INSTALL"; then
		die "$RUNTIME_INSTALL not found on board (apply overlay, build-rootfs, flash)"
	fi
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$RUNTIME_INSTALL"
fi

echo "debug-deploy: uploading debug app payload..."
usb_ssh_session_run_ssh "$ROOT" "$IFACE" "rm -rf $DEVICE_APP_STAGE && mkdir -p $DEVICE_APP_STAGE/data/flutter_assets"
usb_ssh_session_run_scp "$ROOT" "$IFACE" -r \
	"$STAGING/opt/hmi/." \
	"$TARGET_USER@$TARGET_ADDR:$DEVICE_APP_STAGE/"

if ! usb_ssh_session_run_ssh "$ROOT" "$IFACE" "test -x $APP_APPLY"; then
	die "$APP_APPLY not found on board (apply overlay, build-rootfs, flash)"
fi
usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$APP_APPLY"
echo "debug-deploy: done"
