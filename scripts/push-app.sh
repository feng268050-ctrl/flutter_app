#!/usr/bin/env bash
# Deploy Flutter app artifacts to target over USB-SSH or registered remote SSH (make push-app).
# USB-SSH and LAN SSH share this path; only transport selection differs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

STAGING="/var/lib/hmi/push-app-staging"
APPLY_SCRIPT="/usr/libexec/hmi/push-app-apply-and-restart.sh"
APPLY_SCRIPT_HOST="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/push-app-apply-and-restart.sh"
APPLY_LOG="/var/lib/hmi/push-app-restart.log"
APPLY_STATUS="/var/lib/hmi/push-app-apply.status"
OVERLAY_HMI="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/opt/hmi"
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

upload_with_progress() {
	local src="$1"
	local dest="$2"
	python3 "$ROOT/scripts/stream-file-progress.py" "$src" |
		remote "cat >'$dest'"
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

wait_line_rendered=0
# Same single-line progress style as stream-file-progress.py (stderr + \r).
# Do not pad to a fixed width: %-100s wraps on narrow terminals and \r cannot
# rewind past the wrap, so each tick looks like a new line.
clear_wait_line() {
	if [[ "$wait_line_rendered" -eq 1 ]]; then
		printf '\r\033[K' >&2
		wait_line_rendered=0
	fi
}

render_wait_line() {
	local msg="$1"
	local cols
	cols="$(tput cols 2>/dev/null || echo 80)"
	[[ "$cols" =~ ^[0-9]+$ ]] || cols=80
	((cols < 20)) && cols=20
	if ((${#msg} >= cols)); then
		msg="${msg:0:$((cols - 1))}"
	fi
	printf '\r\033[K%s' "$msg" >&2
	wait_line_rendered=1
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

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/hmi-push-app.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

echo "Transferring libapp.so..."
remote "rm -rf $STAGING && mkdir -p $STAGING/lib $STAGING/data/flutter_assets"
upload_with_progress "$LIBAPP" "$STAGING/lib/libapp.so"

echo "Transferring flutter_assets..."
ASSETS_TAR="$STAGE/flutter_assets.tar"
tar -C "$ASSETS" -cf "$ASSETS_TAR" .
upload_with_progress "$ASSETS_TAR" "$STAGING/flutter_assets.tar"
remote "tar -xf '$STAGING/flutter_assets.tar' -C '$STAGING/data/flutter_assets' && rm -f '$STAGING/flutter_assets.tar'"

echo "Installing staged app and restarting hmi.service..."
if [[ ! -f "$APPLY_SCRIPT_HOST" ]]; then
	die "missing host apply script: $APPLY_SCRIPT_HOST"
fi
# Refresh board helper each push so Weston/flutter-pi recovery checks stay current
# without requiring a full rootfs rebuild for script-only fixes.
upload_with_progress "$APPLY_SCRIPT_HOST" "$APPLY_SCRIPT"
remote "chmod 0755 '$APPLY_SCRIPT'"

if ! remote "test -x $APPLY_SCRIPT"; then
	die "$APPLY_SCRIPT not found on board (rebuild rootfs and flash the DRM teardown fix)"
fi

# Detach on the board so push-app survives brief SSH loss while hmi restarts
# (Wi-Fi must live outside hmi cgroup; host still polls completion). USB + LAN.
remote "rm -f $APPLY_LOG $APPLY_STATUS; \
	setsid nohup $APPLY_SCRIPT >$APPLY_LOG 2>&1 </dev/null & \
	echo PUSH_APP_APPLY_STARTED"

echo "Waiting for board apply (max ${APPLY_WAIT_SEC}s)..."
deadline=$((SECONDS + APPLY_WAIT_SEC))
spinner_frame=0
status_poll_tick=0
st=""
log=""
tail1=""
while ((SECONDS < deadline)); do
	spinner_frame=$((spinner_frame % 3 + 1))
	case "$spinner_frame" in
	1) dots=".  " ;;
	2) dots=".. " ;;
	3) dots="..." ;;
	esac
	elapsed=$((APPLY_WAIT_SEC - (deadline - SECONDS)))
	detail=""
	if [[ -n "$tail1" ]]; then
		detail=" — ${tail1:0:60}"
	fi
	render_wait_line "  Waiting for board apply${dots} (${elapsed}s)${detail}"

	if [[ "$status_poll_tick" -eq 0 ]]; then
		# Silence ssh client stderr so host warnings do not break the \r line.
		st="$(remote "cat $APPLY_STATUS 2>/dev/null || true" 2>/dev/null | tr -d '\r' | head -n1 || true)"
		log="$(remote "cat $APPLY_LOG 2>/dev/null || true" 2>/dev/null || true)"
		if apply_ok "$st" "$log"; then
			clear_wait_line
			printf '%s\n' "$log"
			echo "push-app: done (hmi.service restarted with the new app)."
			exit 0
		fi
		if apply_fail "$st" "$log"; then
			clear_wait_line
			printf '%s\n' "$log" >&2
			die "board apply failed (see $APPLY_LOG on device)"
		fi
		tail1="$(printf '%s\n' "$log" | tail -n1 | tr -d '\r')"
	fi

	status_poll_tick=$(( (status_poll_tick + 1) % 4 ))
	sleep 0.25
done

clear_wait_line
printf '%s\n' "$(remote "cat $APPLY_LOG 2>/dev/null || true" || true)" >&2
die "timed out waiting for board apply after ${APPLY_WAIT_SEC}s (see $APPLY_LOG on device)"
