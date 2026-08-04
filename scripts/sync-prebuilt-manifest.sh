#!/usr/bin/env bash
# Best-effort update of prebuilt/manifest.json from on-disk stamps.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/prebuilt/manifest.json"
source "$ROOT/scripts/prebuilt-common.sh"

read_stamp() {
  local dir="$1"
  if prebuilt_ready "$dir"; then
    tr -d '[:space:]' < "$dir/.lws-prebuilt"
    return 0
  fi
  echo "null"
}

MEDIAMTX="$(read_stamp "$ROOT/prebuilt/mediamtx/linux-arm64")"
BTOP="$(read_stamp "$ROOT/prebuilt/btop/aarch64")"
RKNN_RT="$(read_stamp "$ROOT/prebuilt/rknn-rt")"
FLUTTER_SDK_ROOT="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print-root)"
FLUTTER_SDK="$(read_stamp "$FLUTTER_SDK_ROOT")"
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.41.9")"
FLUTTER_ENGINE="$(read_stamp "$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-release")"
ELINUX_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-embedded-linux.version" "42d3d75a56")"
FLUTTER_ELINUX="$(read_stamp "$ROOT/prebuilt/flutter-embedded-linux/${ELINUX_VER}")"
GST="$(read_stamp "$ROOT/prebuilt/gstreamer")"
PLATFORM="$(read_stamp "$ROOT/prebuilt/platform-packages")"

python3 - "$MANIFEST" "$MEDIAMTX" "$BTOP" "$RKNN_RT" "$FLUTTER_SDK" "$FLUTTER_ENGINE" "$FLUTTER_ELINUX" "$GST" "$PLATFORM" <<'PY'
import json, sys
path, mediamtx, btop, rknn, sdk, engine, elinux, gst, platform = sys.argv[1:10]
def v(s):
    return None if s == "null" else s
data = {
    "comment": "Updated by build-* scripts. Used for docs only.",
    "mediamtx": v(mediamtx),
    "btop": v(btop),
    "rknn-rt": v(rknn),
    "gstreamer": v(gst),
    "platform-packages": v(platform),
    "flutter-sdk": v(sdk),
    "flutter-engine": v(engine),
    "flutter-embedded-linux": v(elinux),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "sync-prebuilt-manifest: updated $MANIFEST"
