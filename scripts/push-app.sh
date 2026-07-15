#!/usr/bin/env bash
# Deploy Flutter app artifacts to target over USB-SSH or registered remote SSH (make push-app).
# USB-SSH and LAN SSH share this path; only transport selection differs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

STAGING="/var/lib/lws-hmi/push-app-staging"
APPLY_SCRIPT="/usr/lib/lws-hmi/push-app-apply-and-restart.sh"
APPLY_LOG="/var/lib/lws-hmi/push-app-restart.log"
APPLY_STATUS="/var/lib/lws-hmi/push-app-apply.status"
OVERLAY_HMI="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/opt/hmi"
LIBAPP="$OVERLAY_HMI/lib/libapp.so"
ASSETS="$OVERLAY_HMI/data/flutter_assets"
# Detach apply: LAN SSH over Wi-Fi must not hold the session through hmi stop
# (legacy images killed wpa/dhcp in the hmi cgroup). Same poll path for USB/LAN.
APPLY_WAIT_SEC="${PUSH_APP_APPLY_WAIT_SEC:-120}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Deploy libapp.so + flutter_assets to /opt/hmi over SSH, then restart hmi.service.

Env:
  SERIAL / LWS_HMI_SERIAL        select board when multiple devices
  IP / LWS_HMI_IP                registered SSH only (make connect <ip>)
  LWS_HMI_USB_SSH_PASS           root password (default: rockchip)
  PUSH_APP_WAIT_SEC              ping wait before deploy (default: 30)
  PUSH_APP_APPLY_WAIT_SEC        wait for detached apply (default: 120)

Prereq: make build-app (artifacts in overlay opt/hmi)
Host: sshpass required (see error message if missing)

The board must include the DRM GEM teardown fix before using in-place restart.
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

apply_ok() {
	local st="$1" log="$2"
	[[ "$st" == "ok" ]] && return 0
	# Compat: older boards without status file.
	printf '%s\n' "$log" | grep -q 'restart complete'
}

apply_fail() {
	local st="$1" log="$2"
	[[ "$st" == "fail" ]] && return 0
	printf '%s\n' "$log" | grep -qE 'did not recover|failed to activate'
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

[[ -f "$LIBAPP" ]] || die "missing $LIBAPP (run: make build-app)"
[[ -d "$ASSETS" ]] || die "missing $ASSETS (run: make build-app)"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH push-app: target=$TARGET_USER@$TARGET_ADDR"
else
	echo "USB-SSH push-app: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
fi
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "Staging libapp.so..."
remote "rm -rf $STAGING && mkdir -p $STAGING/lib $STAGING/data/flutter_assets"
usb_ssh_session_run_scp "$ROOT" "$IFACE" "$LIBAPP" "$TARGET_USER@$TARGET_ADDR:$STAGING/lib/libapp.so"

echo "Staging flutter_assets..."
usb_ssh_session_run_scp "$ROOT" "$IFACE" -r "$ASSETS/." "$TARGET_USER@$TARGET_ADDR:$STAGING/data/flutter_assets/"

echo "Installing staged app and restarting hmi.service..."
if ! remote "test -x $APPLY_SCRIPT"; then
	die "$APPLY_SCRIPT not found on board (rebuild rootfs and flash the DRM teardown fix)"
fi

# Detach on the board so push-app survives brief SSH loss while hmi restarts
# (Wi-Fi must live outside hmi cgroup; host still polls completion). USB + LAN.
remote "rm -f $APPLY_LOG $APPLY_STATUS; \
	setsid nohup $APPLY_SCRIPT >$APPLY_LOG 2>&1 </dev/null & \
	echo PUSH_APP_APPLY_STARTED"

echo "Waiting for board apply (max ${APPLY_WAIT_SEC}s)..."
for ((i = 1; i <= APPLY_WAIT_SEC; i++)); do
	st="$(remote "cat $APPLY_STATUS 2>/dev/null || true" | tr -d '\r' | head -n1 || true)"
	log="$(remote "cat $APPLY_LOG 2>/dev/null || true" || true)"
	if apply_ok "$st" "$log"; then
		printf '%s\n' "$log"
		echo "push-app: done (hmi.service restarted with the new app)."
		exit 0
	fi
	if apply_fail "$st" "$log"; then
		printf '%s\n' "$log" >&2
		die "board apply failed (see $APPLY_LOG on device)"
	fi
	if ((i == 1 || i % 5 == 0)); then
		tail1="$(printf '%s\n' "$log" | tail -n1)"
		echo "  still applying... (${i}s)${tail1:+ — $tail1}"
	fi
	sleep 1
done

printf '%s\n' "$(remote "cat $APPLY_LOG 2>/dev/null || true" || true)" >&2
die "timed out waiting for board apply after ${APPLY_WAIT_SEC}s (see $APPLY_LOG on device)"
