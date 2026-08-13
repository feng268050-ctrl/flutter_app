#!/usr/bin/env bash
# Trigger HMI present-hook screen record; Ctrl+C or DURATION=N → pull output/record-screen/.
# Spec: Ctrl+C after a successful save MUST exit 0 (not 130).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

CMD_PATH="/run/hmi/capture.cmd"
STATUS_PATH="/var/lib/hmi/capture/status"
HOST_OUT="${HOST_OUT:-$ROOT/output/record-screen}"
FPS="${FPS:-30}"
SCALE="${SCALE:-100}"
ROTATE="${ROTATE:-0}"
AUDIO="${AUDIO:-0}"
DURATION="${DURATION:-0}"
WAIT_SEC="${WAIT_SEC:-120}"

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

write_cmd() {
	local line="$1"
	remote "mkdir -p /run/hmi /var/lib/hmi/capture && printf '%s\n' '${line}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"
}

wait_status_prefix() {
	local want="$1" i st
	st=""
	for ((i = 0; i < WAIT_SEC * 5; i++)); do
		st="$(remote "cat '${STATUS_PATH}' 2>/dev/null | head -1 | tr -d '\r'" || true)"
		st="${st%%$'\n'*}"
		if [[ "$st" == "$want"* ]] || [[ "$st" == error:* ]]; then
			printf '%s\n' "$st"
			return 0
		fi
		# Interrupted sleep must not abort under set -e (Ctrl+C → stop path).
		sleep 0.2 || true
	done
	die "timeout waiting for status~$want (last: ${st:-empty})"
}

fmt_time() {
	local s="$1"
	printf '%02d:%02d' $((s / 60)) $((s % 60))
}

pull_and_cleanup() {
	local out_dir stamp host_dir
	out_dir="$(remote "grep -E '^out_dir=' '${STATUS_PATH}' 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'" || true)"
	[[ -n "$out_dir" ]] || die "missing out_dir in status"
	remote "test -f '${out_dir}/screen.mp4'" || die "missing ${out_dir}/screen.mp4"

	stamp="$(basename "$out_dir")"
	mkdir -p "$HOST_OUT"
	host_dir="$HOST_OUT/$stamp"
	rm -rf "$host_dir"
	mkdir -p "$host_dir"
	scp_from "${out_dir}/screen.mp4" "$host_dir/screen.mp4"
	scp_from "${out_dir}/summary.txt" "$host_dir/summary.txt" || true
	ln -sfn "$stamp" "$HOST_OUT/rec-latest"

	write_cmd "cleanup ${out_dir}" || true
	sleep 0.5 || true
	remote "rm -rf '${out_dir}'" || true

	echo ""
	echo "OK: $host_dir"
	echo "OK: $HOST_OUT/rec-latest -> $stamp"
}

STOP_REQUESTED=0
on_interrupt() {
	# Do not exit here — break the wait loop, then stop/pull → exit 0.
	STOP_REQUESTED=1
}

finalize_and_exit_ok() {
	local st
	echo ""
	write_cmd "record-stop" || true
	st="$(wait_status_prefix done)"
	if [[ "$st" == error:* ]]; then
		die "device capture failed: $st"
	fi
	pull_and_cleanup
	trap - INT TERM
	exit 0
}

main() {
	usb_ssh_session_load_env "$ROOT"
	usb_ssh_session_select "$ROOT"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "${WAIT_SEC:-30}"

	trap on_interrupt INT TERM

	write_cmd "record-start fps=${FPS} scale=${SCALE} rotate=${ROTATE} audio=${AUDIO}"
	local st
	st="$(wait_status_prefix recording)"
	if [[ "$st" == error:* ]]; then
		die "device capture failed: $st"
	fi

	local start_ts now elapsed
	start_ts="$(date +%s)"
	echo "Recording (Ctrl+C to stop)…"
	while true; do
		if [[ "$STOP_REQUESTED" == "1" ]]; then
			break
		fi
		now="$(date +%s)"
		elapsed=$((now - start_ts))
		if [[ "$DURATION" =~ ^[1-9][0-9]*$ ]] && ((elapsed >= DURATION)); then
			break
		fi
		if [[ "$DURATION" =~ ^[1-9][0-9]*$ ]]; then
			printf '\rRecording %s / %s' "$(fmt_time "$elapsed")" "$(fmt_time "$DURATION")"
		else
			printf '\rRecording %s (Ctrl+C to stop)' "$(fmt_time "$elapsed")"
		fi
		# Ctrl+C during sleep returns 130; ignore so we can finalize.
		sleep 0.25 || true
	done

	finalize_and_exit_ok
}

main "$@"
