#!/usr/bin/env bash
# Remove Buildroot output trees (toolchain switch / defconfig profile change).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$(bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true)"
PROFILE="${BR_OUTPUT:-${1:-}}"

if [[ -z "$PROFILE" && -r "${SDK}/output/.config" ]]; then
  PROFILE="$(sed -n 's/^RK_BUILDROOT_BASE_CFG="\(.*\)"$/\1/p' "${SDK}/output/.config")"
fi
PROFILE="${PROFILE:-rockchip_rk3566_rk3568_lws_hmi}"

OUT_BASE="${SDK}/buildroot/output"
TARGET="${OUT_BASE}/${PROFILE}"

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
echo "clean-buildroot-output: done (kept buildroot/dl/)"
echo "  Next: make apply-overlay && make lunch && make build-rootfs"
