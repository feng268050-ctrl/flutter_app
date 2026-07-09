#!/usr/bin/env bash
# Download RKNN Linux aarch64 runtime (runtime — libai.so + board NPU inference).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/rknn-toolkit.version"
PREBUILT_SO="$ROOT/prebuilt/rknn-rt/aarch64/librknnrt.so"
PREBUILT_HEADER="$ROOT/prebuilt/rknn-rt/include/rknn_api.h"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${RKNN_RT_VERSION:-}" ]]; then
    echo "$RKNN_RT_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" "2.3.2"
}

VERSION="$(read_version)"
BASE="https://github.com/airockchip/rknn-toolkit2/raw/v${VERSION}"

if prebuilt_ready "$ROOT/prebuilt/rknn-rt" && [[ "$FORCE" != "1" ]]; then
  echo "fetch-rknn-rt: prebuilt ready under prebuilt/rknn-rt/"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -f "$PREBUILT_SO" "$PREBUILT_HEADER"
  rm -f "$ROOT/prebuilt/rknn-rt/.lws-prebuilt"
fi

mkdir -p "$(dirname "$PREBUILT_SO")" "$(dirname "$PREBUILT_HEADER")"

SRC_SO="${BASE}/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so"
SRC_HEADER="${BASE}/rknpu2/runtime/Linux/librknn_api/include/rknn_api.h"

echo "fetch-rknn-rt: downloading RKNN Linux runtime v${VERSION} (aarch64) ..."
curl -fL --retry 3 --retry-delay 2 -o "$PREBUILT_SO" "$SRC_SO"
curl -fL --retry 3 --retry-delay 2 -o "$PREBUILT_HEADER" "$SRC_HEADER"

if [[ ! -s "$PREBUILT_SO" ]]; then
  echo "ERROR: downloaded librknnrt.so is empty" >&2
  exit 1
fi

prebuilt_stamp "$ROOT/prebuilt/rknn-rt" "$VERSION"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
echo "fetch-rknn-rt: done"
echo "  $PREBUILT_SO"
echo "  $PREBUILT_HEADER"
