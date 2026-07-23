#!/usr/bin/env bash
# Compare scalar BGR→NCHW preprocess vs cv::dnn::blobFromImage within FP tolerance.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build-host/compare_stain_preprocess}"
BIN="$BUILD_DIR/compare_stain_preprocess"
TOLERANCE="${TOLERANCE:-1e-5}"

mkdir -p "$BUILD_DIR"
g++ -std=c++17 -O2 \
  "$ROOT/tools/compare_stain_preprocess/main.cpp" \
  -o "$BIN" \
  $(pkg-config --cflags --libs opencv4 2>/dev/null || pkg-config --cflags --libs opencv)

IMAGE="${1:-}"
if [[ -n "$IMAGE" ]]; then
  exec "$BIN" "$IMAGE" "$TOLERANCE"
fi
exec "$BIN" "$TOLERANCE"
