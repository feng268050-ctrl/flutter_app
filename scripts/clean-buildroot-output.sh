#!/usr/bin/env bash
# Remove Buildroot output trees (toolchain switch / defconfig profile change).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
source "$ROOT/scripts/prebuilt-common.sh"

OUT_BASE="${SDK}/buildroot/output"
TARGET="$(resolve_br_output_dir "$SDK")"
if [[ -n "${BR_OUTPUT:-${1:-}}" ]]; then
  TARGET="${OUT_BASE}/${BR_OUTPUT:-$1}"
fi

if [[ ! -d "$OUT_BASE" ]]; then
  echo "clean-buildroot-output: no buildroot/output — nothing to do"
  exit 0
fi

if [[ ! -d "$TARGET" ]]; then
  echo "clean-buildroot-output: $TARGET not found"
  exit 0
fi

echo "clean-buildroot-output: removing $TARGET"
rm -rf "$TARGET"
# Mali variant stamp would lie after wiping BR output — force next ensure rebuild.
rm -f "$ROOT/.cache/lws-mali-variant"
echo "clean-buildroot-output: done (kept buildroot/dl/; cleared .cache/lws-mali-variant)"
echo "  Next: make apply-overlay && make lunch && make build-rootfs"
