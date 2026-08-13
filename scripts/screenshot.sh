#!/usr/bin/env bash
# Trigger HMI present-hook screenshot and pull to output/screenshot/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/capture-host-common.sh
source "$ROOT/scripts/capture-host-common.sh"

CMD_PATH="/run/hmi/capture.cmd"
STATUS_PATH="/var/lib/hmi/capture/status"
HOST_OUT="${HOST_OUT:-$ROOT/output/screenshot}"
ROTATE="${ROTATE:-0}"
Q="${Q:-80}"
WAIT_SEC="${WAIT_SEC:-60}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

scp_from() {
	local src="$1" dest="$2"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"${TARGET_USER:-root}@${TARGET_ADDR}:$src" "$dest"
}

main() {
	usb_ssh_session_load_env "$ROOT"
	usb_ssh_session_select "$ROOT"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" 30

	capture_host_mkdir
	capture_host_preflight_clear 20
	capture_host_read_status
	local seq0="${CAPTURE_HOST_SEQ:-0}"
	echo "capture seq before=${seq0} status=${CAPTURE_HOST_STATUS:-empty}" >&2

	capture_host_write_cmd "screenshot rotate=${ROTATE} q=${Q}"

	local st out_dir stamp host_dir
	st="$(capture_host_wait_status done "$seq0" "$WAIT_SEC")"
	if [[ "$st" == error:* ]]; then
		die "device capture failed: $st"
	fi

	out_dir="$(remote "grep -E '^out_dir=' '${STATUS_PATH}' 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'" || true)"
	[[ -n "$out_dir" ]] || die "missing out_dir in status"
	remote "test -f '${out_dir}/screen.jpg'" || die "missing ${out_dir}/screen.jpg"

	stamp="$(basename "$out_dir")"
	mkdir -p "$HOST_OUT"
	host_dir="$HOST_OUT/$stamp"
	rm -rf "$host_dir"
	mkdir -p "$host_dir"
	scp_from "${out_dir}/screen.jpg" "$host_dir/screen.jpg"
	scp_from "${out_dir}/summary.txt" "$host_dir/summary.txt" || true
	ln -sfn "$stamp" "$HOST_OUT/shot-latest"

	capture_host_write_cmd "cleanup ${out_dir}" || true
	remote "rm -rf '${out_dir}'" || true

	echo "OK: $host_dir"
	echo "OK: $HOST_OUT/shot-latest -> $stamp"
}

main "$@"
