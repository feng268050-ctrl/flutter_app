#!/usr/bin/env bash
# Resolve Rockchip MPP include/lib for arm64 Android cross-compile (StreamDetect).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ABI="${ANDROID_ABI:-arm64-v8a}"
MPP_ROOT="${ROCKCHIP_MPP_ROOT:-$ROOT/native/toolchains/rockchip-mpp/$ABI}"

INCLUDE_DIR="${ROCKCHIP_MPP_INCLUDE_DIR:-$MPP_ROOT/include}"
LIB_DIR="${ROCKCHIP_MPP_LIB_DIR:-$MPP_ROOT/lib}"
LIB="${ROCKCHIP_MPP_LIB:-$LIB_DIR/libmpp.so}"

if [[ ! -f "$INCLUDE_DIR/rk_mpi.h" && -f "$INCLUDE_DIR/rockchip/rk_mpi.h" ]]; then
  INCLUDE_DIR="$INCLUDE_DIR/rockchip"
fi

if [[ -f "$INCLUDE_DIR/rk_mpi.h" && -f "$LIB" ]]; then
  echo "ROCKCHIP_MPP_INCLUDE_DIR=$INCLUDE_DIR"
  echo "ROCKCHIP_MPP_LIB=$LIB"
  exit 0
fi

echo "Rockchip MPP not found under $MPP_ROOT (need include/rk_mpi.h and lib/libmpp.so)" >&2
echo "Run: scripts/make/fetch-rockchip-mpp.sh && adb pull /vendor/lib64/libmpp.so $LIB" >&2
exit 1
