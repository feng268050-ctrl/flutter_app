#!/usr/bin/env bash
# Build GStreamer + MPP stack in Buildroot, export → prebuilt/gstreamer/target (before build-rootfs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION="$(read_version_file "$ROOT/overlay/third-party/gstreamer.version" "rockchip-mpp-gst-rtsp")"
STAMP_DIR="$ROOT/prebuilt/gstreamer/target"
FORCE="${FORCE:-0}"

GST_PACKAGES=(
  rockchip-mpp
  rockchip-rga
  gstreamer1-rockchip
  gstreamer1
  gst1-plugins-base
  gst1-plugins-good
  gst1-plugins-bad
  gst1-plugins-ugly
)

if prebuilt_ready "$STAMP_DIR" && [[ "$FORCE" != "1" ]]; then
  echo "build-gstreamer: prebuilt ready at $STAMP_DIR"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ROOT/prebuilt/gstreamer"
fi

bash "$ROOT/scripts/br-make-packages.sh" gstreamer "${GST_PACKAGES[@]}"

BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
bash "$ROOT/scripts/docker-run.sh" bash -lc "
  OUT=\"\${LWS_HMI_SDK_DIR:?}/buildroot/output/${BR_OUTPUT}\"
  test -x \"\$OUT/target/usr/bin/gst-launch-1.0\"
"

bash "$ROOT/scripts/export-runtime-prebuilt.sh" gstreamer

echo "build-gstreamer: done — prebuilt at $STAMP_DIR (make apply-overlay && make build-rootfs)"
