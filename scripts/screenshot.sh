#!/usr/bin/env bash
# Trigger HMI present-hook screenshot and pull to output/screenshot/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

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

wait_status() {
	local want="$1" i st
	st=""
	for ((i = 0; i < WAIT_SEC * 5; i++)); do
		st="$(remote "cat '${STATUS_PATH}' 2>/dev/null | head -1 | tr -d '\r'" || true)"
		st="${st%%$'\n'*}"
		if [[ "$st" == "$want" ]] || [[ "$st" == error:* ]]; then
			printf '%s\n' "$st"
			return 0
		fi
		sleep 0.2
	done
	die "timeout waiting for status=$want (last: ${st:-empty})"
}

main() {
	usb_ssh_session_load_env "$ROOT"
	usb_ssh_session_select "$ROOT"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "${WAIT_SEC:-30}"

	remote "mkdir -p /run/hmi /var/lib/hmi/capture && printf '%s\n' 'screenshot rotate=${ROTATE} q=${Q}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

	local st out_dir stamp host_dir
	st="$(wait_status done)"
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

	remote "printf '%s\n' 'cleanup ${out_dir}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'" || true
	sleep 0.5
	remote "rm -rf '${out_dir}'" || true

	echo "OK: $host_dir"
	echo "OK: $HOST_OUT/shot-latest -> $stamp"
}

main "$@"
