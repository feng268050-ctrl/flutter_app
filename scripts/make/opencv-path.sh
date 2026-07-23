#!/usr/bin/env bash
set -euo pipefail

# Resolve OPENCV_PATH (sdk/native/jni). Prints the path on stdout.
#
# Usage:
#   eval "$(scripts/make/opencv-path.sh)"
#   OPENCV_PATH="$(scripts/make/opencv-path.sh)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT="$ROOT/native/toolchains/opencv/sdk/native/jni"

if [[ -n "${OPENCV_PATH:-}" ]]; then
  printf '%s\n' "$OPENCV_PATH"
  exit 0
fi

if [[ -f "$DEFAULT/OpenCVConfig.cmake" ]]; then
  printf '%s\n' "$DEFAULT"
  exit 0
fi

echo "ERROR: OpenCV not found. Run 'make opencv' or set OPENCV_PATH to OpenCV-android-sdk/sdk/native/jni" >&2
exit 1
