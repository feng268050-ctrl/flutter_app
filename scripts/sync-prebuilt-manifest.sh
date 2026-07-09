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
RKNN_RT="$(read_stamp "$ROOT/prebuilt/rknn-rt")"
FLUTTER_SDK_ROOT="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print-root)"
FLUTTER_SDK="$(read_stamp "$FLUTTER_SDK_ROOT")"
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
FLUTTER_ENGINE="$(read_stamp "$ROOT/prebuilt/flutter-engine/${ENGINE_VER}/arm64-release")"
PI_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-pi.version" "")"
FLUTTER_PI="$(read_stamp "$ROOT/prebuilt/flutter-pi/${PI_VER}")"
GST="$(read_stamp "$ROOT/prebuilt/gstreamer")"
PLATFORM="$(read_stamp "$ROOT/prebuilt/platform-packages")"

python3 - "$MANIFEST" "$MEDIAMTX" "$RKNN_RT" "$FLUTTER_SDK" "$FLUTTER_ENGINE" "$FLUTTER_PI" "$GST" "$PLATFORM" <<'PY'
import json, sys
path, mediamtx, rknn, sdk, engine, pi, gst, platform = sys.argv[1:9]
def v(s):
    return None if s == "null" else s
data = {
    "comment": "Updated by build-* scripts. Used for docs only.",
    "mediamtx": v(mediamtx),
    "rknn-rt": v(rknn),
    "gstreamer": v(gst),
    "platform-packages": v(platform),
    "flutter-sdk": v(sdk),
    "flutter-engine": v(engine),
    "flutter-pi": v(pi),
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

echo "sync-prebuilt-manifest: updated $MANIFEST"
