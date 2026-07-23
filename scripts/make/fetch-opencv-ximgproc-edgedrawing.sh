#!/usr/bin/env bash
set -euo pipefail

# Vendor OpenCV contrib ximgproc EdgeDrawing sources (4.5.5, matches native/toolchains/opencv/VERSION).
# The stock OpenCV Android SDK does not ship opencv_ximgproc; we compile edge_drawing.cpp in-tree.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR_DIR="$ROOT/native/toolchains/opencv-ximgproc-ed"
VERSION_FILE="$ROOT/native/toolchains/opencv/VERSION"
MARKER="$VENDOR_DIR/src/edge_drawing.cpp"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: missing $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
BASE="https://raw.githubusercontent.com/opencv/opencv_contrib/${VERSION}/modules/ximgproc"

if [[ -f "$MARKER" ]]; then
  echo "fetch-opencv-ximgproc-edgedrawing: already present at $VENDOR_DIR"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

mkdir -p "$VENDOR_DIR/src" "$VENDOR_DIR/include/opencv2/ximgproc"

fetch() {
  local rel="$1"
  local dest="$VENDOR_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  echo "fetch-opencv-ximgproc-edgedrawing: $rel"
  curl -fsSL "$BASE/$rel" -o "$dest"
}

fetch "src/edge_drawing.cpp"
fetch "src/edge_drawing_common.hpp"
fetch "include/opencv2/ximgproc/edge_drawing.hpp"

echo "fetch-opencv-ximgproc-edgedrawing: installed EdgeDrawing sources under $VENDOR_DIR"
