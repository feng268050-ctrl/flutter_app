#!/usr/bin/env bash
# Verify prebuilt artifacts required by the active lws_hmi defconfig (#include lines).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

bash "$ROOT/scripts/generate-lws-hmi-defconfig.sh" >/dev/null

DEF="$ROOT/overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
GEN="$ROOT/overlay/buildroot/.generated/rockchip_rk3566_rk3568_lws_hmi_defconfig"
[[ -f "$GEN" ]] && DEF="$GEN"

def_includes() {
  grep -E '^#include "chips/lws_hmi_[^"]+\.config"' "$DEF" 2>/dev/null || true
}

has_include() {
  def_includes | grep -qF "#include \"chips/$1\""
}

ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
PI_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-pi.version" "")"
GST_VER="$(read_version_file "$ROOT/overlay/third-party/gstreamer.version" "rockchip-mpp-gst-rtsp")"
OPENCV_VER="$(read_version_file "$ROOT/overlay/third-party/opencv.version" "4.5.5")"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"

ENGINE_DIR="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}"
PI_DIR="$ROOT/prebuilt/flutter-pi/${PI_VER}"
MEDIAMTX_DIR="$ROOT/prebuilt/mediamtx/linux-arm64"
RKNN_RT_DIR="$ROOT/prebuilt/rknn-rt"
GST_EXPORT="$ROOT/prebuilt/gstreamer/target"
PLATFORM_EXPORT="$ROOT/prebuilt/platform-packages/target"
OPENCV_CACHE="$ROOT/.cache/opencv"
OPENCV_TAR="$OPENCV_CACHE/opencv-${OPENCV_VER}.tar.gz"
CONTRIB_TAR="$OPENCV_CACHE/opencv_contrib-${OPENCV_VER}.tar.gz"
XIMGPROC_MARKER="$OPENCV_CACHE/ximgproc-ed/src/edge_drawing.cpp"

require_prebuilt() {
  local label="$1" dir="$2" hint="${3:-make build-runtime-deps}"
  if ! prebuilt_ready "$dir"; then
    echo "ERROR: $label missing: $dir" >&2
    echo "  Run: $hint" >&2
    return 1
  fi
}

require_file() {
  local label="$1" path="$2" hint="${3:-make build-runtime-deps}"
  if [[ ! -f "$path" ]]; then
    echo "ERROR: $label missing: $path" >&2
    echo "  Run: $hint" >&2
    return 1
  fi
}

missing=0

if has_include "lws_hmi_flutter.config"; then
  require_prebuilt "flutter-engine" "$ENGINE_DIR" \
    "make build-flutter-engine / make build-runtime-deps" || missing=1
  require_prebuilt "flutter-pi" "$PI_DIR" \
    "make build-flutter-pi / make build-runtime-deps" || missing=1
fi

if has_include "lws_hmi_mediamtx.config"; then
  require_prebuilt "mediamtx" "$MEDIAMTX_DIR" \
    "make build-mediamtx / make build-runtime-deps" || missing=1
fi

if has_include "lws_hmi_npu.config"; then
  require_prebuilt "rknn-rt" "$RKNN_RT_DIR" \
    "make fetch-rknn-rt / make build-runtime-deps" || missing=1
  require_file "opencv sources" "$OPENCV_TAR" "make fetch-opencv" || missing=1
  require_file "opencv_contrib sources" "$CONTRIB_TAR" "make fetch-opencv" || missing=1
  require_file "opencv ximgproc" "$XIMGPROC_MARKER" "make fetch-opencv-ximgproc" || missing=1
fi

if has_include "lws_hmi_gst_rtsp.config" || has_include "lws_hmi_gst_prebuilt.config"; then
  if ! prebuilt_ready "$GST_EXPORT"; then
    echo "ERROR: gstreamer prebuilt missing: $GST_EXPORT" >&2
    echo "  Run: make build-gstreamer  (before make build-rootfs)" >&2
    missing=1
  fi
fi

if has_include "lws_hmi_platform.config" || has_include "lws_hmi_platform_prebuilt.config"; then
  if ! prebuilt_ready "$PLATFORM_EXPORT"; then
    echo "ERROR: platform-packages prebuilt missing: $PLATFORM_EXPORT" >&2
    echo "  Run: make build-platform-packages  (before make build-rootfs)" >&2
    missing=1
  fi
fi

if [[ "$missing" != "0" ]]; then
  echo "check-prebuilt: failed (see active includes in overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig)" >&2
  exit 1
fi

echo "check-prebuilt: OK"
echo "  defconfig: $(basename "$DEF")"
def_includes | sed 's/^/  /'
if has_include "lws_hmi_flutter.config"; then
  echo "  engine: $ENGINE_DIR"
  echo "  flutter-pi: $PI_DIR"
fi
