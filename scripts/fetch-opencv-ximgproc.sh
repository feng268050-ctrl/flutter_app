#!/usr/bin/env bash
# Vendor OpenCV contrib ximgproc EdgeDrawing sources (matches overlay/third-party/opencv.version).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/overlay/third-party/opencv.version"
VENDOR_DIR="$ROOT/.cache/opencv/ximgproc-ed"
MARKER="$VENDOR_DIR/src/edge_drawing.cpp"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${OPENCV_VERSION:-}" ]]; then
    echo "$OPENCV_VERSION"
    return 0
  fi
  if [[ -f "$VERSION_FILE" ]]; then
    tr -d '[:space:]' < "$VERSION_FILE"
    return 0
  fi
  echo "4.5.5"
}

VERSION="$(read_version)"
BASE="https://raw.githubusercontent.com/opencv/opencv_contrib/${VERSION}/modules/ximgproc"

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$VENDOR_DIR"
fi

if [[ -f "$MARKER" ]]; then
  echo "build-opencv-ximgproc: already present at $VENDOR_DIR"
  exit 0
fi

mkdir -p "$VENDOR_DIR/src" "$VENDOR_DIR/include/opencv2/ximgproc"

fetch() {
  local rel="$1"
  local dest="$VENDOR_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  echo "build-opencv-ximgproc: $rel"
  curl -fsSL "$BASE/$rel" -o "$dest"
}

fetch "src/edge_drawing.cpp"
fetch "src/edge_drawing_common.hpp"
fetch "include/opencv2/ximgproc/edge_drawing.hpp"

echo "build-opencv-ximgproc: installed under $VENDOR_DIR"
