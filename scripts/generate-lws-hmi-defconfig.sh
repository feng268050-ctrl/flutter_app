#!/usr/bin/env bash
# Render Buildroot defconfig: source #includes + auto prebuilt swap when exports exist.
# Default stack is Weston + eLinux. Set LWS_HMI_WESTON=0 for the alternate flutter-pi image.
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

# Default source defconfig is Weston. Alternate flutter-pi (LWS_HMI_WESTON=0):
# Buildroot keeps the first assignment for conflicting symbols — replace the
# Weston/eLinux includes with lws_hmi_flutter.config (which clears Wayland pkgs).
case "${LWS_HMI_WESTON:-1}" in
0 | n | N | no | NO | false | FALSE)
  sed -i.bak \
    's|#include "chips/lws_hmi_flutter_weston.config"|#include "chips/lws_hmi_flutter.config"|' \
    "$OUT"
  sed -i.bak '/^#include "chips\/lws_hmi_wayland\.config"$/d' "$OUT"
  rm -f "$OUT.bak"
  echo "generate-lws-hmi-defconfig: LWS_HMI_WESTON=0 → flutter-pi alternate"
  ;;
*)
  echo "generate-lws-hmi-defconfig: default Weston stack (LWS_HMI_WESTON=${LWS_HMI_WESTON:-1})"
  ;;
esac

echo "generate-lws-hmi-defconfig: → $OUT"
