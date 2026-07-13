#!/usr/bin/env bash
# Deploy Flutter app artifacts to target over USB ECM SSH (make push-app).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

STAGING="/var/lib/lws-hmi/push-app-staging"
APPLY_SCRIPT="/usr/lib/lws-hmi/push-app-apply-and-restart.sh"
OVERLAY_HMI="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/opt/hmi"
LIBAPP="$OVERLAY_HMI/lib/libapp.so"
ASSETS="$OVERLAY_HMI/data/flutter_assets"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Deploy libapp.so + flutter_assets to /opt/hmi over USB ECM SSH, then restart hmi.service.

Env:
  SERIAL / LWS_HMI_SERIAL        select board when multiple USB-SSH devices connected
  LWS_HMI_USB_SSH_PASS           root password (default: rockchip)
  PUSH_APP_WAIT_SEC              ping wait before deploy (default: 30)

Prereq: make build-app (artifacts in overlay opt/hmi)
Host: sshpass required for USB-SSH (see error message if missing)

The board must include the DRM GEM teardown fix before using in-place restart.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

[[ -f "$LIBAPP" ]] || die "missing $LIBAPP (run: make build-app)"
[[ -d "$ASSETS" ]] || die "missing $ASSETS (run: make build-app)"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"

echo "USB-SSH push-app: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
configure_usb_ssh_host_addr "$IFACE"
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "Staging libapp.so..."
usb_ssh_session_run_ssh "$ROOT" "$IFACE" "rm -rf $STAGING && mkdir -p $STAGING/lib $STAGING/data/flutter_assets"
usb_ssh_session_run_scp "$ROOT" "$IFACE" "$LIBAPP" "$TARGET_USER@$TARGET_ADDR:$STAGING/lib/libapp.so"

echo "Staging flutter_assets..."
usb_ssh_session_run_scp "$ROOT" "$IFACE" -r "$ASSETS/." "$TARGET_USER@$TARGET_ADDR:$STAGING/data/flutter_assets/"

echo "Installing staged app and restarting hmi.service..."
if usb_ssh_session_run_ssh "$ROOT" "$IFACE" "test -x $APPLY_SCRIPT"; then
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$APPLY_SCRIPT"
else
	die "$APPLY_SCRIPT not found on board (rebuild rootfs and flash the DRM teardown fix)"
fi

echo "push-app: done (hmi.service restarted with the new app)."
