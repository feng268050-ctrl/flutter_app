#!/usr/bin/env bash
# Deploy Flutter app artifacts to target over USB ECM SSH (make push-app).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"
SERIAL="${SERIAL:-${LWS_HMI_SERIAL:-}}"
TARGET_ADDR="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
TARGET_USER="${LWS_HMI_USB_SSH_USER:-root}"
SSH_PASS="${LWS_HMI_USB_SSH_PASS:-rockchip}"
WAIT_SEC="${PUSH_APP_WAIT_SEC:-30}"
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

sel=()
while IFS= read -r line; do
	sel+=("$line")
done < <(SERIAL="$SERIAL" bash "$ROOT/scripts/usb-ssh-devices.sh" --select)
[[ ${#sel[@]} -eq 3 ]] || die "could not select USB-SSH device"
IFACE="${sel[1]}"
[[ "$IFACE" != "-" && -n "$IFACE" ]] || die "no host interface for USB-SSH device (wait for ECM link)"

wait_for_target() {
	local i
	for ((i = 1; i <= WAIT_SEC; i++)); do
		if ping_usb_ssh_target "$IFACE" >/dev/null 2>&1; then
			echo "Target reachable on $TARGET_ADDR via $IFACE (${i}s)."
			return 0
		fi
		if (( i == 1 || i % 5 == 0 )); then
			echo "Waiting for $TARGET_ADDR on $IFACE... (${i}s)"
		fi
		sleep 1
	done
	die "Timed out waiting for $TARGET_ADDR on $IFACE (plug USB, wait for ECM)"
}

ssh_base_opts=(
	-o ConnectTimeout=5
	-o StrictHostKeyChecking=accept-new
	-o UserKnownHostsFile=/dev/null
	-o LogLevel=ERROR
)
while IFS= read -r opt; do
	[[ -n "$opt" ]] && ssh_base_opts+=("$opt")
done < <(usb_ssh_bind_pair "$IFACE")

run_ssh() {
	require_sshpass
	sshpass -p "$SSH_PASS" ssh "${ssh_base_opts[@]}" "$TARGET_USER@$TARGET_ADDR" "$@"
}

run_ssh_optional() {
	command -v sshpass >/dev/null 2>&1 || return 1
	sshpass -p "$SSH_PASS" ssh "${ssh_base_opts[@]}" "$TARGET_USER@$TARGET_ADDR" "$@" 2>/dev/null || return 1
}

run_scp() {
	require_sshpass
	sshpass -p "$SSH_PASS" scp "${ssh_base_opts[@]}" "$@"
}

apply_and_restart() {
	echo "Installing staged app and restarting hmi.service..."
	if run_ssh_optional "test -x $APPLY_SCRIPT"; then
		run_ssh "$APPLY_SCRIPT"
	else
		die "$APPLY_SCRIPT not found on board (rebuild rootfs and flash the DRM teardown fix)"
	fi
}

echo "USB-SSH push-app: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
configure_usb_ssh_host_addr "$IFACE"
wait_for_target

echo "Staging libapp.so..."
run_ssh "rm -rf $STAGING && mkdir -p $STAGING/lib $STAGING/data/flutter_assets"
run_scp "$LIBAPP" "$TARGET_USER@$TARGET_ADDR:$STAGING/lib/libapp.so"

echo "Staging flutter_assets..."
run_scp -r "$ASSETS/." "$TARGET_USER@$TARGET_ADDR:$STAGING/data/flutter_assets/"

apply_and_restart

echo "push-app: done (hmi.service restarted with the new app)."
