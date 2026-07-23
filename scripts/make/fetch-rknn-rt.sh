#!/usr/bin/env bash
set -euo pipefail

# Vendor RKNN Android runtime (librknnrt.so + rknn_api.h) from airockchip/rknn-toolkit2.
#
# This is intentionally separate from `make rknn` (ONNX→RKNN conversion tooling).
#
# Output layout (mirrors upstream):
#   native/toolchains/rknn-rt/rknpu2/runtime/Android/librknn_api/arm64-v8a/librknnrt.so
#   native/toolchains/rknn-rt/rknpu2/runtime/Android/librknn_api/include/rknn_api.h
#
# Usage:
#   scripts/make/fetch-rknn-rt.sh
#
# Optional env:
#   RKNN_VERSION=2.3.2           # default: scripts/make/rknn/VERSION
#   AI_ANDROID_ABI=arm64-v8a     # default arm64-v8a

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RKNN_VERSION_FILE="$ROOT/scripts/make/rknn/VERSION"

if [[ -n "${RKNN_VERSION:-}" ]]; then
  VERSION="$RKNN_VERSION"
elif [[ -f "$RKNN_VERSION_FILE" ]]; then
  VERSION="$(tr -d '[:space:]' < "$RKNN_VERSION_FILE")"
else
  echo "ERROR: missing $RKNN_VERSION_FILE (cannot infer RKNN version)" >&2
  exit 1
fi

ABI="${AI_ANDROID_ABI:-arm64-v8a}"
VENDOR_ROOT="$ROOT/native/toolchains/rknn-rt"
DEST_DIR="$VENDOR_ROOT/rknpu2/runtime/Android/librknn_api/$ABI"
DEST_SO="$DEST_DIR/librknnrt.so"
DEST_INCLUDE_DIR="$VENDOR_ROOT/rknpu2/runtime/Android/librknn_api/include"
DEST_HEADER="$DEST_INCLUDE_DIR/rknn_api.h"

if [[ -f "$DEST_SO" && -f "$DEST_HEADER" ]]; then
  echo "fetch-rknn-rt: already present: $DEST_SO"
  echo "fetch-rknn-rt: already present: $DEST_HEADER"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

mkdir -p "$DEST_DIR" "$DEST_INCLUDE_DIR"

BASE="https://github.com/airockchip/rknn-toolkit2/raw/v${VERSION}"
SRC_SO="${BASE}/rknpu2/runtime/Android/librknn_api/${ABI}/librknnrt.so"
SRC_HEADER="${BASE}/rknpu2/runtime/Android/librknn_api/include/rknn_api.h"

echo "fetch-rknn-rt: downloading RKNN Android runtime v${VERSION} (${ABI}) ..."
echo "fetch-rknn-rt: source: ${SRC_SO}"
curl -fL --retry 3 --retry-delay 2 -o "$DEST_SO" "$SRC_SO"
echo "fetch-rknn-rt: source: ${SRC_HEADER}"
curl -fL --retry 3 --retry-delay 2 -o "$DEST_HEADER" "$SRC_HEADER"

if [[ ! -s "$DEST_SO" ]]; then
  echo "ERROR: downloaded librknnrt.so is empty: $DEST_SO" >&2
  exit 1
fi

echo "fetch-rknn-rt: done: $DEST_SO"
echo "fetch-rknn-rt: done: $DEST_HEADER"

