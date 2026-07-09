#!/usr/bin/env bash
# Download OpenCV + opencv_contrib source (P3 libai cross-build). Aligned with lws-ui OpenCV 4.5.5.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/overlay/third-party/opencv.version"
CACHE_DIR="$ROOT/.cache/opencv"
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
OPENCV_TAR="$CACHE_DIR/opencv-${VERSION}.tar.gz"
CONTRIB_TAR="$CACHE_DIR/opencv_contrib-${VERSION}.tar.gz"
OPENCV_URL="https://github.com/opencv/opencv/archive/${VERSION}.tar.gz"
CONTRIB_URL="https://github.com/opencv/opencv_contrib/archive/${VERSION}.tar.gz"

if [[ "$FORCE" == "1" ]]; then
  rm -f "$OPENCV_TAR" "$CONTRIB_TAR"
fi

mkdir -p "$CACHE_DIR"

download() {
  local url="$1" dest="$2" label="$3"
  if [[ -f "$dest" ]]; then
    echo "build-opencv: using cached $label"
    return 0
  fi
  echo "build-opencv: downloading $label ..."
  curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
}

download "$OPENCV_URL" "$OPENCV_TAR" "opencv-${VERSION}"
download "$CONTRIB_URL" "$CONTRIB_TAR" "opencv_contrib-${VERSION}"

echo "build-opencv: ready (OpenCV ${VERSION} sources in $CACHE_DIR)"
echo "  $OPENCV_TAR"
echo "  $CONTRIB_TAR"
echo "  Next: make build-opencv-ximgproc  (optional EdgeDrawing sources for libai)"
