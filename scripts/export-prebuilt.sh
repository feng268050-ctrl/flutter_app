#!/usr/bin/env bash
# Export Buildroot output → prebuilt/ (flutter + optional gst/platform runtime).
#
# Replaces separate make build-prebuilt + make export-prebuilt-runtime.
#
# Env (auto by default):
#   EXPORT_FLUTTER=1|0   — flutter-engine (and optional host SDK)
#   EXPORT_RUNTIME=1|0   — gstreamer + platform-packages from target/
#   PACK_*               — passed through to flutter export (see build-prebuilt.sh)
#   FORCE=1              — overwrite existing prebuilt trees
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    bash -c 'export LWS_HMI_DOCKER=1 LWS_HMI_SDK_DIR=/work/sdk; exec bash /work/lws-hmi/scripts/export-prebuilt.sh'
fi

source "$ROOT/scripts/prebuilt-common.sh"

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
PROFILE="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
TARGET="$SDK/buildroot/output/${PROFILE}/target"

DEF="$ROOT/overlay/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
GEN="$ROOT/overlay/buildroot/.generated/rockchip_rk3566_rk3568_lws_hmi_defconfig"
bash "$ROOT/scripts/generate-lws-hmi-defconfig.sh" >/dev/null
[[ -f "$GEN" ]] && DEF="$GEN"

def_includes() {
  grep -E '^#include "chips/lws_hmi_[^"]+\.config"' "$DEF" 2>/dev/null || true
}

has_include() {
  def_includes | grep -qF "#include \"chips/$1\""
}

want_flutter() {
  [[ "${EXPORT_FLUTTER:-}" == "0" ]] && return 1
  [[ "${EXPORT_FLUTTER:-}" == "1" ]] && return 0
  has_include "lws_hmi_flutter_weston.config"
}

want_runtime() {
  [[ "${EXPORT_RUNTIME:-}" == "0" ]] && return 1
  [[ "${EXPORT_RUNTIME:-}" == "1" ]] && return 0
  has_include "lws_hmi_gst_rtsp.config" \
    || has_include "lws_hmi_gst_prebuilt.config" \
    || has_include "lws_hmi_platform.config" \
    || has_include "lws_hmi_platform_prebuilt.config"
}

runtime_ready() {
  [[ -d "$TARGET/usr" ]] \
    && [[ -x "$TARGET/usr/bin/gst-launch-1.0" || -f "$TARGET/usr/lib/libmodbus.so" ]] \
    && compgen -G "$TARGET/usr/lib/libmodbus.so*" >/dev/null 2>&1
}

did=0

if want_flutter; then
  echo "export-prebuilt: flutter (engine / optional SDK) ..."
  bash "$ROOT/scripts/build-prebuilt.sh"
  did=1
else
  echo "export-prebuilt: skip flutter (not in defconfig; EXPORT_FLUTTER=1 to force)"
fi

if want_runtime; then
  if runtime_ready; then
    echo "export-prebuilt: runtime (gstreamer + platform-packages) ..."
    bash "$ROOT/scripts/export-runtime-prebuilt.sh" all
    did=1
  else
    echo "export-prebuilt: skip runtime — run make build-gstreamer / build-platform-packages first" >&2
  fi
else
  echo "export-prebuilt: skip runtime (not in defconfig; EXPORT_RUNTIME=1 to force)"
fi

if [[ "$did" -eq 0 ]]; then
  echo "ERROR: nothing exported — check defconfig includes and Buildroot output" >&2
  exit 1
fi

echo "export-prebuilt: done — make apply-overlay && make build-rootfs"
