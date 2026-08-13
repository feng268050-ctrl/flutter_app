#!/usr/bin/env bash
# Shared helpers for peripheral firmware host HTTP + device download
# (control-board / camera). Sourced by upgrade-control-board.sh / upgrade-camera.sh.
#
# Expects ROOT to be set to the repo root. Sets / uses:
#   OTA_HTTP_HOST / OTA_HTTP_PORT / OTA_SIGNING_KEY
#   IFACE / TARGET_ADDR / WAIT_SEC / TRANSPORT (via usb-ssh-session)

peripheral_ota_die() {
	echo "ERROR: $*" >&2
	exit 1
}

peripheral_ota_resolve_signing_key() {
	if [[ -n "${OTA_SIGNING_KEY:-}" ]]; then
		[[ -r "$OTA_SIGNING_KEY" ]] || peripheral_ota_die "OTA_SIGNING_KEY not readable: $OTA_SIGNING_KEY"
		return 0
	fi
	local default_key="$ROOT/keys/ota/ed25519.pem"
	if [[ -r "$default_key" ]]; then
		OTA_SIGNING_KEY="$default_key"
		return 0
	fi
	peripheral_ota_die "OTA_SIGNING_KEY unset and $default_key missing — run: make sign-keys"
}

peripheral_ota_sign() {
	local input="$1"
	local output="${2:-${input}.sig}"
	peripheral_ota_resolve_signing_key
	OTA_SIGNING_KEY="$OTA_SIGNING_KEY" bash "$ROOT/scripts/ota-sign.sh" "$input" "$output" \
		|| peripheral_ota_die "ota-sign failed for $input"
	[[ -f "$output" ]] || peripheral_ota_die "signature missing after ota-sign: $output"
}

# Resolve IPv4 the device uses to reach this host's ephemeral HTTP server.
peripheral_ota_resolve_http_bind() {
	if [[ -n "${OTA_HTTP_HOST:-}" ]]; then
		OTA_HTTP_BIND="$OTA_HTTP_HOST"
		return 0
	fi
	case "${TRANSPORT:-}" in
	usb-ssh)
		OTA_HTTP_BIND="${USB_HOST_ADDR:-${USB_SSH_HOST_ADDR:-192.168.55.2}}"
		return 0
		;;
	esac
	OTA_HTTP_BIND="$(
		python3 - "$TARGET_ADDR" <<'PY'
import socket
import sys

target = sys.argv[1]
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect((target, 1))
    print(s.getsockname()[0])
finally:
    s.close()
PY
	)" || peripheral_ota_die "failed to resolve OTA_HTTP_HOST toward $TARGET_ADDR"
	[[ -n "$OTA_HTTP_BIND" ]] || peripheral_ota_die "empty OTA_HTTP_BIND"
}

# Args: package_path sig_path basename [basename.sig implied]
# Sets: OTA_HTTP_PID OTA_HTTP_BASE OTA_HTTP_SERVE_DIR OTA_HTTP_LOG PACKAGE_URL
peripheral_ota_start_http_server() {
	local package="$1"
	local sig="$2"
	local base_name="$3"
	local port="${OTA_HTTP_PORT:-0}"
	local log
	local sig_name="${base_name}.sig"

	OTA_HTTP_SERVE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-peripheral-http.XXXXXX")"
	ln "$package" "$OTA_HTTP_SERVE_DIR/$base_name" 2>/dev/null \
		|| cp -f "$package" "$OTA_HTTP_SERVE_DIR/$base_name"
	ln "$sig" "$OTA_HTTP_SERVE_DIR/$sig_name" 2>/dev/null \
		|| cp -f "$sig" "$OTA_HTTP_SERVE_DIR/$sig_name"

	log="$(mktemp "${TMPDIR:-/tmp}/lws-peripheral-http-log.XXXXXX")"
	python3 "$ROOT/scripts/ota-http-serve.py" \
		--bind "$OTA_HTTP_BIND" \
		--port "$port" \
		--dir "$OTA_HTTP_SERVE_DIR" \
		--file "$base_name" \
		--file "$sig_name" \
		>"$log" &
	OTA_HTTP_PID=$!
	OTA_HTTP_LOG="$log"
	local i line
	for ((i = 0; i < 50; i++)); do
		if ! kill -0 "$OTA_HTTP_PID" 2>/dev/null; then
			cat "$log" >&2 || true
			peripheral_ota_die "ota-http-serve exited early (bind $OTA_HTTP_BIND:$port)"
		fi
		line="$(head -n1 "$log" 2>/dev/null || true)"
		if [[ "$line" == http://* ]]; then
			OTA_HTTP_BASE="${line%/}/"
			# URL-encode spaces in basename for HTTP path.
			PACKAGE_URL="${OTA_HTTP_BASE}$(
				python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$base_name"
			)"
			return 0
		fi
		sleep 0.1
	done
	kill "$OTA_HTTP_PID" 2>/dev/null || true
	cat "$log" >&2 || true
	peripheral_ota_die "ota-http-serve did not print base URL"
}

peripheral_ota_stop_http_server() {
	if [[ -n "${OTA_HTTP_PID:-}" ]]; then
		kill "$OTA_HTTP_PID" 2>/dev/null || true
		wait "$OTA_HTTP_PID" 2>/dev/null || true
		OTA_HTTP_PID=""
	fi
	if [[ -n "${OTA_HTTP_SERVE_DIR:-}" && -d "${OTA_HTTP_SERVE_DIR:-}" ]]; then
		rm -rf "$OTA_HTTP_SERVE_DIR"
		OTA_HTTP_SERVE_DIR=""
	fi
	if [[ -n "${OTA_HTTP_LOG:-}" ]]; then
		rm -f "$OTA_HTTP_LOG"
		OTA_HTTP_LOG=""
	fi
}

peripheral_ota_wait_transfer_complete() {
	local timeout="${1:-600}"
	local i
	for ((i = 0; i < timeout * 10; i++)); do
		if ! kill -0 "${OTA_HTTP_PID:-0}" 2>/dev/null; then
			peripheral_ota_die "ota-http-serve exited before TRANSFER_COMPLETE"
		fi
		if grep -qx 'TRANSFER_COMPLETE' "${OTA_HTTP_LOG:-/dev/null}" 2>/dev/null; then
			return 0
		fi
		sleep 0.1
	done
	peripheral_ota_die "timed out waiting for host HTTP TRANSFER_COMPLETE (${timeout}s)"
}
