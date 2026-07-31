#!/usr/bin/env bash
# ximgproc EdgeDrawing sources for board libai / lws_ai_daemon (runtime OpenCV stack).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/overlay/third-party/opencv.version"
VENDOR_DIR="$ROOT/.cache/opencv/ximgproc-ed"
MARKER="$VENDOR_DIR/src/edge_drawing.cpp"
PRECOMP="$VENDOR_DIR/src/precomp.hpp"
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

if [[ -f "$MARKER" && -f "$PRECOMP" ]]; then
  echo "fetch-opencv-ximgproc: already present at $VENDOR_DIR"
  exit 0
fi

mkdir -p "$VENDOR_DIR/src" "$VENDOR_DIR/include/opencv2/ximgproc"

fetch() {
  local rel="$1"
  local dest="$VENDOR_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  echo "fetch-opencv-ximgproc: $rel"
  curl -fsSL "$BASE/$rel" -o "$dest"
}

fetch "src/edge_drawing.cpp"
fetch "src/edge_drawing_common.hpp"
fetch "include/opencv2/ximgproc/edge_drawing.hpp"

# Minimal precomp (upstream private.hpp is not suitable out-of-tree).
cat >"$PRECOMP" <<'EOF'
/*
 * Minimal precomp for vendored OpenCV contrib edge_drawing.cpp (no opencv2/core/private.hpp).
 */
#ifndef OPENCV_XIMGPROC_ED_PRECOMP_HPP_
#define OPENCV_XIMGPROC_ED_PRECOMP_HPP_

#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/ximgproc/edge_drawing.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

#endif
EOF

echo "fetch-opencv-ximgproc: installed under $VENDOR_DIR"
