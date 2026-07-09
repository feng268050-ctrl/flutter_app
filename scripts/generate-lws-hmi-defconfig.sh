#!/usr/bin/env bash
# Render Buildroot defconfig: source #includes + auto prebuilt swap when exports exist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

SRC="$ROOT/overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
GEN_DIR="$ROOT/overlay/buildroot/.generated"
OUT="$GEN_DIR/rockchip_rk3566_rk3568_lws_hmi_defconfig"

[[ -f "$SRC" ]] || { echo "ERROR: missing $SRC" >&2; exit 1; }

mkdir -p "$GEN_DIR"
cp "$SRC" "$OUT"

swap_include() {
  local compile="$1" prebuilt="$2" prebuilt_dir="$3"
  if grep -qF "#include \"chips/${compile}\"" "$OUT" && prebuilt_ready "$prebuilt_dir"; then
    sed -i.bak "s|#include \"chips/${compile}\"|#include \"chips/${prebuilt}\"|" "$OUT"
    rm -f "$OUT.bak"
    echo "generate-lws-hmi-defconfig: ${compile} → ${prebuilt} (export ready)"
  fi
}

swap_include "lws_hmi_gst_rtsp.config" "lws_hmi_gst_prebuilt.config" \
  "$ROOT/prebuilt/gstreamer/target"
swap_include "lws_hmi_platform.config" "lws_hmi_platform_prebuilt.config" \
  "$ROOT/prebuilt/platform-packages/target"

echo "generate-lws-hmi-defconfig: → $OUT"
