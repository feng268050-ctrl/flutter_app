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
APPLY_SCRIPT="/usr/lib/lws-hmi/push-app-apply-and-reboot.sh"

OVERLAY_HMI="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/opt/hmi"
LIBAPP="$OVERLAY_HMI/lib/libapp.so"
ASSETS="$OVERLAY_HMI/data/flutter_assets"

# Remote sysrq reboot — see USB_SSH_SYSRQ_REBOOT_CMD in usb-ssh-common.sh

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Deploy libapp.so + flutter_assets to /opt/hmi over USB ECM SSH, then trigger sysrq reboot.

Env:
  SERIAL / LWS_HMI_SERIAL        select board when multiple USB-SSH devices connected
  LWS_HMI_USB_SSH_PASS           root password (default: rockchip)
  PUSH_APP_WAIT_SEC              ping wait before deploy (default: 30)

Prereq: make build-app (artifacts in overlay opt/hmi)
Host: sshpass required for USB-SSH (see error message if missing)

Does not wait for the board to finish rebooting.
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

install_from_staging() {
	run_ssh "install -D -m 0644 $STAGING/lib/libapp.so /opt/hmi/lib/libapp.so && cp -a $STAGING/data/flutter_assets/. /opt/hmi/data/flutter_assets/ && sync && echo lws-hmi-push-app: install done >/dev/console"
}

schedule_sysrq_reboot() {
	echo "Scheduling sysrq reboot..."
	usb_ssh_schedule_sysrq_reboot "$IFACE"
	echo "Reboot triggered."
}

apply_and_reboot() {
	echo "Installing staged app to /opt/hmi..."
	if run_ssh_optional "test -x $APPLY_SCRIPT"; then
		run_ssh "$APPLY_SCRIPT" || true
	else
		echo "NOTE: $APPLY_SCRIPT not on board — inline install + sysrq reboot"
		install_from_staging
		schedule_sysrq_reboot
	fi
}

echo "USB-SSH push-app: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
configure_usb_ssh_host_addr "$IFACE"
wait_for_target

echo "Staging libapp.so..."
run_ssh "mkdir -p $STAGING/lib $STAGING/data/flutter_assets"
run_scp "$LIBAPP" "$TARGET_USER@$TARGET_ADDR:$STAGING/lib/libapp.so"

echo "Staging flutter_assets..."
run_scp -r "$ASSETS/." "$TARGET_USER@$TARGET_ADDR:$STAGING/data/flutter_assets/"

apply_and_reboot

echo "push-app: done (board rebooting — new app loads on next boot)."
