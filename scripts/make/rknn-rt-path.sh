#!/usr/bin/env bash
set -euo pipefail

# Resolve vendored RKNN Android runtime directory that contains librknnrt.so.
#
# Usage:
#   scripts/make/rknn-rt-path.sh
#   RKNN_RT_PATH="$(scripts/make/rknn-rt-path.sh)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ABI="${AI_ANDROID_ABI:-arm64-v8a}"
VENDOR_RT="$ROOT/native/toolchains/rknn-rt/rknpu2/runtime/Android/librknn_api/${ABI}"
VENDOR_HEADER="$ROOT/native/toolchains/rknn-rt/rknpu2/runtime/Android/librknn_api/include/rknn_api.h"

if [[ -f "$VENDOR_RT/librknnrt.so" && -f "$VENDOR_HEADER" ]]; then
  printf '%s\n' "$VENDOR_RT"
  exit 0
fi

cat >&2 <<EOF
ERROR: vendored RKNN Android runtime not found at:
  $VENDOR_RT/librknnrt.so
  $VENDOR_HEADER

Run once from the repo root:
  make rknn-rt

Or set RKNN_RT_PATH to an existing runtime directory containing librknnrt.so.
EOF
exit 1

