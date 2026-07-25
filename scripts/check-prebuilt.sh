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
ELINUX_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-embedded-linux.version" "db49896cf2")"
GST_VER="$(read_version_file "$ROOT/overlay/third-party/gstreamer.version" "rockchip-mpp-gst-rtsp")"
OPENCV_VER="$(read_version_file "$ROOT/overlay/third-party/opencv.version" "4.5.5")"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"

ENGINE_DIR="$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-${RUNTIME_MODE}"
ELINUX_DIR="$ROOT/prebuilt/flutter-embedded-linux/${ELINUX_VER}"
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

if has_include "lws_hmi_flutter_weston.config"; then
  require_prebuilt "flutter-engine" "$ENGINE_DIR" \
    "make build-flutter-engine / make build-runtime-deps" || missing=1
fi

if has_include "lws_hmi_wayland.config"; then
  require_prebuilt "flutter-embedded-linux" "$ELINUX_DIR" \
    "make build-flutter-embedded-linux" || missing=1
  if [[ -f "$ELINUX_DIR/.lws-prebuilt" ]] && \
    [[ ! -x "$ELINUX_DIR/usr/bin/flutter-wayland-client" ]]; then
    echo "ERROR: flutter-embedded-linux missing usr/bin/flutter-wayland-client" >&2
    missing=1
  fi
  if [[ -f "$ELINUX_DIR/.lws-prebuilt" ]] && \
    { [[ ! -f "$ELINUX_DIR/.lws-gstreamer-video-player" ]] || \
      [[ ! -f "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" ]]; }; then
    echo "ERROR: flutter-embedded-linux missing GStreamer video player plugin" >&2
    echo "  Run: make build-flutter-embedded-linux" >&2
    missing=1
  fi
  # Live RTSP preview needs 0002-video-player-live-rtsp.patch (null caps /
  # NO_PREROLL). Unpatched plugin SIGSEGVs in GetVideoSize during initialize.
  if [[ -f "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" ]] && \
    ! strings "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" | \
      grep -q 'Video size unknown after preroll'; then
    echo "ERROR: libvideo_player_plugin.so missing live-RTSP patch marker" >&2
    echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
    missing=1
  fi
  # Flutter play() always setPlaybackSpeed → flush seek stalls live RTSP (black preview).
  if [[ -f "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" ]] && \
    ! strings "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" | \
      grep -q 'skip flush-seek for live/unseekable'; then
    echo "ERROR: libvideo_player_plugin.so missing live-seek patch marker" >&2
    echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
    missing=1
  fi
  # Non-blocking Create(): must not g_usleep-poll for live caps on platform thread.
  if [[ -f "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" ]] && \
    ! strings "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" | \
      grep -q 'using 960x540 placeholder'; then
    echo "ERROR: libvideo_player_plugin.so missing nonblock-init marker" >&2
    echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
    missing=1
  fi
  # MPP hardware RGBA — software videoconvert is ~1fps on RK3566.
  if [[ -f "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" ]] && \
    ! strings "$ELINUX_DIR/usr/lib/libvideo_player_plugin.so" | \
      grep -q 'MppElementSetup: mppvideodec format=RGBA'; then
    echo "ERROR: libvideo_player_plugin.so missing MPP RGBA setup marker" >&2
    echo "  Run: FORCE=1 make rebuild-flutter-embedded-linux" >&2
    missing=1
  fi
fi

if has_include "lws_hmi_mediamtx.config"; then
  require_prebuilt "mediamtx" "$MEDIAMTX_DIR" \
    "make build-mediamtx / make build-runtime-deps" || missing=1
fi

if has_include "lws_hmi_npu.config"; then
  require_prebuilt "rknn-rt" "$RKNN_RT_DIR" \
    "make fetch-rknn-rt / make build-runtime-deps" || missing=1
  require_file "librknnrt.so overlay" \
    "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/lib/librknnrt.so" \
    "make fetch-rknn-rt" || missing=1
  require_file "rknn_server overlay" \
    "$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/bin/rknn_server" \
    "make fetch-rknn-rt" || missing=1
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
if has_include "lws_hmi_flutter_weston.config"; then
  echo "  engine: $ENGINE_DIR"
fi
if has_include "lws_hmi_wayland.config"; then
  echo "  flutter-embedded-linux: $ELINUX_DIR"
fi
