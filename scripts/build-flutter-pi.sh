#!/usr/bin/env bash
# Fetch flutter-pi sources (if needed), compile via Buildroot, export → prebuilt/flutter-pi/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-pi.version"
REPO="${FLUTTER_PI_REPO:-https://github.com/ardera/flutter-pi.git}"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${FLUTTER_PI_VERSION:-}" ]]; then
    echo "$FLUTTER_PI_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" ""
}

VERSION="$(read_version)"
if [[ -z "$VERSION" ]]; then
  grep -E '^FLUTTER_PI_VERSION[[:space:]]*=' \
    "$ROOT/overlay/buildroot/package/flutter-pi/flutter-pi.mk" 2>/dev/null \
    | awk '{print $3}' || true
fi
if [[ -z "$VERSION" ]]; then
  echo "ERROR: could not determine FLUTTER_PI_VERSION" >&2
  exit 1
fi

PI_PREBUILT="$ROOT/prebuilt/flutter-pi/${VERSION}"
SRC="$ROOT/.cache/flutter-pi/src"
DEFCONFIG="$ROOT/overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
GST_VIDEO_STAMP="$PI_PREBUILT/.lws-gstreamer-video-player"
GST_VIDEO_REQUIRED=0
if grep -qE '^#include "chips/lws_hmi_gst_(rtsp|prebuilt)\.config"' "$DEFCONFIG"; then
  GST_VIDEO_REQUIRED=1
fi

if prebuilt_ready "$PI_PREBUILT" &&
  [[ "$FORCE" != "1" ]] &&
  { [[ "$GST_VIDEO_REQUIRED" != "1" ]] || [[ -f "$GST_VIDEO_STAMP" ]]; }; then
  echo "flutter-pi: prebuilt ready at $PI_PREBUILT"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ROOT/.cache/flutter-pi"
  rm -rf "$PI_PREBUILT"
fi

mkdir -p "$(dirname "$SRC")"

if [[ ! -d "$SRC/.git" ]]; then
  echo "flutter-pi: cloning $REPO ..."
  git clone "$REPO" "$SRC"
fi

echo "flutter-pi: checkout $VERSION ..."
git -C "$SRC" fetch origin
git -C "$SRC" checkout -f "$VERSION"

ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"
ENGINE_PREBUILT="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}"
if ! prebuilt_ready "$ENGINE_PREBUILT"; then
  echo "flutter-pi: requires prebuilt flutter-engine at $ENGINE_PREBUILT" >&2
  echo "  Run: make build-flutter-engine" >&2
  exit 1
fi

echo "flutter-pi: compiling in Buildroot ..."
bash "$ROOT/scripts/br-compile-flutter.sh" flutter-pi

PACK_ENGINE=0 PACK_FLUTTER_SDK=0 bash "$ROOT/scripts/build-prebuilt.sh"
if [[ "$GST_VIDEO_REQUIRED" == "1" ]]; then
  touch "$GST_VIDEO_STAMP"
fi

echo "flutter-pi: prebuilt at $PI_PREBUILT"
