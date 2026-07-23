#!/usr/bin/env bash
set -euo pipefail

# Download and install the OpenCV Android SDK into native/toolchains/opencv/sdk/.
#
# Usage:
#   scripts/make/fetch-opencv.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR_DIR="$ROOT/native/toolchains/opencv"
VERSION_FILE="$VENDOR_DIR/VERSION"
CACHE_DIR="$VENDOR_DIR/_cache"
SDK_DIR="$VENDOR_DIR/sdk"
MARKER="$SDK_DIR/native/jni/OpenCVConfig.cmake"
LIBS_DIR="$SDK_DIR/native/libs/arm64-v8a"
STATICLIBS_DIR="$SDK_DIR/native/staticlibs/arm64-v8a"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: missing $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
ZIP_NAME="opencv-${VERSION}-android-sdk.zip"
CACHE_ZIP="$CACHE_DIR/$ZIP_NAME"
URL="https://github.com/opencv/opencv/releases/download/${VERSION}/${ZIP_NAME}"

REQUIRED_MODULES=(core imgproc imgcodecs videoio)

opencv_ready() {
  [[ -f "$MARKER" ]] || return 1
  local mod
  for mod in "${REQUIRED_MODULES[@]}"; do
    if [[ -f "$LIBS_DIR/libopencv_${mod}.a" || -f "$STATICLIBS_DIR/libopencv_${mod}.a" ]]; then
      continue
    fi
    return 1
  done
  return 0
}

if opencv_ready; then
  echo "fetch-opencv: OpenCV ${VERSION} already installed at $SDK_DIR"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip not found" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

if [[ ! -f "$CACHE_ZIP" ]]; then
  echo "fetch-opencv: downloading ${URL} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$CACHE_ZIP" "$URL"
else
  echo "fetch-opencv: using cached archive $CACHE_ZIP"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/opencv-sdk.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "fetch-opencv: extracting..."
unzip -q "$CACHE_ZIP" -d "$TMP"

SDK_SRC="$(find "$TMP" -type d -path '*/OpenCV-android-sdk/sdk' | head -1)"
if [[ -z "$SDK_SRC" || ! -f "$SDK_SRC/native/jni/OpenCVConfig.cmake" ]]; then
  echo "ERROR: OpenCV-android-sdk/sdk not found inside ${ZIP_NAME}" >&2
  exit 1
fi

rm -rf "$SDK_DIR"
mkdir -p "$VENDOR_DIR"
cp -R "$SDK_SRC" "$SDK_DIR"

if ! opencv_ready; then
  echo "ERROR: installed SDK is missing required static modules (libopencv_{core,imgproc,imgcodecs,videoio}.a)" >&2
  exit 1
fi

printf '%s\n' "$VERSION" > "$VENDOR_DIR/installed-version.txt"
echo "fetch-opencv: installed OpenCV ${VERSION} (static libs; linked into libai.so at build time)"
echo "  OPENCV_PATH=$SDK_DIR/native/jni"
echo "  libs=$LIBS_DIR"
