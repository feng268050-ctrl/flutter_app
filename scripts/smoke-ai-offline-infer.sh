#!/usr/bin/env bash
# Board smoke: upload stain demo JPG + run lws_ai_daemon offline RKNN infer via cmd.sock.
#
# Usage:
#   make smoke-ai
#   SN=<sn> bash scripts/smoke-ai-offline-infer.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

IMG_DIR="$ROOT/native/lws_ai/assets/img"
CFG="$ROOT/native/lws_ai/config.yaml"
SMOKE_SRC="$ROOT/native/lws_ai/tools/smoke/unix_json_req.c"
CACHE_DIR="$ROOT/.cache/ai-smoke"
HELPER_BIN="$CACHE_DIR/unix_json_req"
REMOTE_DIR="/var/lib/hmi/ai"
REMOTE_HELPER="/tmp/unix_json_req"
REMOTE_SOCK="/run/hmi/ai/cmd.sock"
IMAGE_NAME="${SMOKE_AI_IMAGE:-stain_demo_1920x1080.jpg}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  make smoke-ai
  SN=<sn> bash scripts/smoke-ai-offline-infer.sh

Uploads native/lws_ai demo assets to /var/lib/hmi/ai, then:
  1) ping on /run/hmi/ai/cmd.sock
  2) offline_infer_rknn_stain_jpg (default image: stain_demo_1920x1080.jpg)

Env:
  SMOKE_AI_IMAGE   basename under native/lws_ai/assets/img (default stain_demo_1920x1080.jpg)
  SN= / IP=   device selection (same as other make targets)
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

scp_to() {
	local src="$1" dest="$2"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"$src" "${TARGET_USER:-root}@${TARGET_ADDR}:$dest"
}

ensure_helper() {
	[[ -f "$SMOKE_SRC" ]] || die "missing $SMOKE_SRC"
	if [[ -x "$HELPER_BIN" ]]; then
		local src_mtime bin_mtime
		src_mtime=$(stat -f %m "$SMOKE_SRC" 2>/dev/null || stat -c %Y "$SMOKE_SRC")
		bin_mtime=$(stat -f %m "$HELPER_BIN" 2>/dev/null || stat -c %Y "$HELPER_BIN")
		if [[ "$bin_mtime" -ge "$src_mtime" ]]; then
			return 0
		fi
	fi
	mkdir -p "$CACHE_DIR"
	echo "==> cross-compile unix_json_req → $HELPER_BIN"
	if [[ "$(uname -s)" == Darwin ]]; then
		env SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" bash -c "
set -euo pipefail
GCC=\$(ls /work/sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc 2>/dev/null | head -1)
[[ -n \"\$GCC\" ]] || GCC=\$(find /work/sdk/prebuilts -name 'aarch64-*-gcc' 2>/dev/null | head -1)
[[ -x \"\$GCC\" ]] || { echo 'ERROR: aarch64 gcc not found in SDK' >&2; exit 1; }
mkdir -p /work/lws-hmi/.cache/ai-smoke
\"\$GCC\" -O2 -static -o /work/lws-hmi/.cache/ai-smoke/unix_json_req \
  /work/lws-hmi/native/lws_ai/tools/smoke/unix_json_req.c
file /work/lws-hmi/.cache/ai-smoke/unix_json_req
"
	else
		local gcc
		gcc="$(find "${SDK_DIR:-$ROOT/linux-sdk}/prebuilts" -name 'aarch64-*-gcc' 2>/dev/null | head -1 || true)"
		[[ -x "$gcc" ]] || die "aarch64 gcc not found (set SDK_DIR or use Docker)"
		"$gcc" -O2 -static -o "$HELPER_BIN" "$SMOKE_SRC"
	fi
	[[ -x "$HELPER_BIN" ]] || die "failed to build $HELPER_BIN"
}

main() {
	case "${1:-}" in
	-h | --help | help)
		usage
		exit 0
		;;
	esac

	local img="$IMG_DIR/$IMAGE_NAME"
	[[ -f "$img" ]] || die "missing demo image: $img"
	[[ -f "$CFG" ]] || die "missing $CFG"
	[[ -f "$IMG_DIR/stain_demo.jpg" ]] || die "missing $IMG_DIR/stain_demo.jpg"

	usb_ssh_session_load_env "$ROOT"
	usb_ssh_session_select "$ROOT"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

	ensure_helper

	echo "==> upload assets → $REMOTE_DIR"
	remote "mkdir -p '$REMOTE_DIR'"
	scp_to "$img" "$REMOTE_DIR/$IMAGE_NAME"
	scp_to "$IMG_DIR/stain_demo.jpg" "$REMOTE_DIR/stain_demo.jpg"
	scp_to "$CFG" "$REMOTE_DIR/config.yaml"
	scp_to "$HELPER_BIN" "$REMOTE_HELPER"
	remote "chmod 755 '$REMOTE_HELPER'"

	echo "==> ping"
	remote "'$REMOTE_HELPER' '$REMOTE_SOCK' '{\"v\":1,\"type\":\"ping\",\"id\":\"smoke-ping\",\"ts_ms\":1}'"
	echo

	local req
	req=$(printf '{"v":1,"type":"offline_infer_rknn_stain_jpg","id":"smoke-rknn","ts_ms":1,"image_path":"%s/%s"}' \
		"$REMOTE_DIR" "$IMAGE_NAME")
	echo "==> offline_infer_rknn_stain_jpg image=$IMAGE_NAME"
	remote "'$REMOTE_HELPER' '$REMOTE_SOCK' '$req'"
	echo
	echo "OK: smoke-ai finished (expect ok:true and summary_json with code:0)"
}

main "$@"
