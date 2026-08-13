#!/usr/bin/env bash
# Build GStreamer + MPP stack in Buildroot, export → prebuilt/gstreamer/target (before build-rootfs).
#
# Cross-compiles (flutter-embedded-linux) need gstreamer-*.pc in Buildroot staging.
# After export, defconfig swaps to lws_hmi_gst_prebuilt (overlay only) — staging may
# lack devel files. This script restores staging when those .pc files are missing
# even if prebuilt/gstreamer is already stamped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION="$(read_version_file "$ROOT/overlay/third-party/gstreamer.version" "rockchip-mpp-gst-rtsp")"
STAMP_DIR="$ROOT/prebuilt/gstreamer/target"
FORCE="${FORCE:-0}"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"

GST_PACKAGES=(
  rockchip-mpp
  rockchip-rga
  gstreamer1-rockchip
  gstreamer1
  gst1-plugins-base
  gst1-plugins-good
  gst1-plugins-bad
)

staging_has_gst_pc() {
  SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" bash -lc "
    OUT=\"\${SDK_DIR:?}/buildroot/output/${BR_OUTPUT}\"
    STAGING=\"\$OUT/staging\"
    test -f \"\$STAGING/usr/lib/pkgconfig/gstreamer-1.0.pc\" &&
      test -f \"\$STAGING/usr/lib/pkgconfig/gstreamer-app-1.0.pc\" &&
      test -f \"\$STAGING/usr/lib/pkgconfig/gstreamer-video-1.0.pc\"
  " >/dev/null 2>&1
}

build_gst_into_br() {
  # generate-lws-hmi-defconfig swaps to gst_prebuilt when the stamp exists.
  # Hide the stamp so docker-run apply-overlay keeps gst_rtsp and BR compiles
  # gstreamer into staging (needed for flutter-embedded-linux pkg-config).
  local stamp="$STAMP_DIR/.lws-prebuilt"
  local bak=""
  if [[ -f "$stamp" ]]; then
    bak="$(mktemp "${TMPDIR:-/tmp}/lws-gst-prebuilt.XXXXXX")"
    mv "$stamp" "$bak"
  fi
  bash "$ROOT/scripts/br-make-packages.sh" gstreamer "${GST_PACKAGES[@]}"
  if [[ -n "$bak" && -f "$bak" ]]; then
    mkdir -p "$STAMP_DIR"
    mv "$bak" "$stamp"
  fi
}

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ROOT/prebuilt/gstreamer"
elif prebuilt_ready "$STAMP_DIR"; then
  if staging_has_gst_pc; then
    echo "build-gstreamer: prebuilt ready at $STAMP_DIR (staging .pc ok)"
    exit 0
  fi
  echo "build-gstreamer: prebuilt ready but staging missing gstreamer-*.pc — restoring BR packages"
  build_gst_into_br
  if ! staging_has_gst_pc; then
    echo "ERROR: staging still missing gstreamer-*.pc after BR rebuild" >&2
    exit 1
  fi
  echo "build-gstreamer: staging restored (prebuilt stamp kept)"
  exit 0
fi

build_gst_into_br

bash "$ROOT/scripts/docker-run.sh" bash -lc "
  OUT=\"\${SDK_DIR:?}/buildroot/output/${BR_OUTPUT}\"
  test -x \"\$OUT/target/usr/bin/gst-launch-1.0\"
"

bash "$ROOT/scripts/export-runtime-prebuilt.sh" gstreamer

echo "build-gstreamer: done — prebuilt at $STAMP_DIR (make apply-overlay && make build-rootfs)"
