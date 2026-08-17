#!/usr/bin/env bash
# Stage RKNN Linux aarch64 runtime for rootfs overlay + libai cross-link.
# Primary source: SDK external/rknpu2 (matches kernel NPU driver).
# Fallback: rknn-toolkit2 github release (overlay/third-party/rknn-toolkit.version).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/rknn-toolkit.version"
PREBUILT_SO="$ROOT/prebuilt/rknn-rt/aarch64/librknnrt.so"
PREBUILT_HEADER="$ROOT/prebuilt/rknn-rt/include/rknn_api.h"
OVERLAY_LIB="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/lib/librknnrt.so"
OVERLAY_BIN="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/bin/rknn_server"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${RKNN_RT_VERSION:-}" ]]; then
    echo "$RKNN_RT_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" "2.3.2"
}

sdk_rknpu_root() {
  local sdk
  sdk="${SDK_DIR:-$ROOT/linux-sdk}"
  [[ -n "$sdk" && -d "$sdk/external/rknpu2" ]] || return 1
  printf '%s/external/rknpu2\n' "$sdk"
}

sync_rootfs_overlay() {
  if [[ -f "$PREBUILT_SO" ]]; then
    mkdir -p "$(dirname "$OVERLAY_LIB")"
    install -m 0644 "$PREBUILT_SO" "$OVERLAY_LIB"
    echo "fetch-rknn-rt: synced → $OVERLAY_LIB"
  fi
  if [[ -x "${RKNN_SERVER_SRC:-}" ]]; then
    mkdir -p "$(dirname "$OVERLAY_BIN")"
    install -m 0755 "$RKNN_SERVER_SRC" "$OVERLAY_BIN"
    echo "fetch-rknn-rt: synced → $OVERLAY_BIN"
  fi
}

VERSION="$(read_version)"

if prebuilt_ready "$ROOT/prebuilt/rknn-rt" && \
   [[ -f "$OVERLAY_LIB" && -x "$OVERLAY_BIN" ]] && \
   [[ "$FORCE" != "1" ]]; then
  echo "fetch-rknn-rt: prebuilt ready under prebuilt/rknn-rt/ and fs-overlay"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -f "$PREBUILT_SO" "$PREBUILT_HEADER" "$OVERLAY_LIB" "$OVERLAY_BIN"
  rm -f "$ROOT/prebuilt/rknn-rt/.lws-prebuilt"
fi

mkdir -p "$(dirname "$PREBUILT_SO")" "$(dirname "$PREBUILT_HEADER")"

RKNPU_ROOT="$(sdk_rknpu_root || true)"
if [[ -n "$RKNPU_ROOT" ]]; then
  SDK_SO="$RKNPU_ROOT/runtime/Linux/librknn_api/aarch64/librknnrt.so"
  SDK_HEADER="$RKNPU_ROOT/runtime/Linux/librknn_api/include/rknn_api.h"
  RKNN_SERVER_SRC="$RKNPU_ROOT/runtime/Linux/rknn_server/aarch64/usr/bin/rknn_server"
  if [[ -f "$SDK_SO" && -f "$SDK_HEADER" && -x "$RKNN_SERVER_SRC" ]]; then
    echo "fetch-rknn-rt: using SDK $RKNPU_ROOT"
    install -m 0644 "$SDK_SO" "$PREBUILT_SO"
    install -m 0644 "$SDK_HEADER" "$PREBUILT_HEADER"
    sync_rootfs_overlay
    prebuilt_stamp "$ROOT/prebuilt/rknn-rt" "sdk-rknpu2"
    bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
    echo "fetch-rknn-rt: done (SDK)"
    echo "  $PREBUILT_SO"
    echo "  $PREBUILT_HEADER"
    echo "  $OVERLAY_LIB"
    echo "  $OVERLAY_BIN"
    exit 0
  fi
  echo "WARNING: SDK rknpu2 runtime incomplete — falling back to github v${VERSION}" >&2
fi

BASE="https://github.com/airockchip/rknn-toolkit2/raw/v${VERSION}"
SRC_SO="${BASE}/rknpu2/runtime/Linux/librknn_api/aarch64/librknnrt.so"
SRC_HEADER="${BASE}/rknpu2/runtime/Linux/librknn_api/include/rknn_api.h"
SRC_SERVER="${BASE}/rknpu2/runtime/Linux/rknn_server/aarch64/usr/bin/rknn_server"

echo "fetch-rknn-rt: downloading RKNN Linux runtime v${VERSION} (aarch64) ..."
curl -fL --retry 3 --retry-delay 2 -o "$PREBUILT_SO" "$SRC_SO"
curl -fL --retry 3 --retry-delay 2 -o "$PREBUILT_HEADER" "$SRC_HEADER"
curl -fL --retry 3 --retry-delay 2 -o "$OVERLAY_BIN" "$SRC_SERVER"
chmod 0755 "$OVERLAY_BIN"
RKNN_SERVER_SRC="$OVERLAY_BIN"

if [[ ! -s "$PREBUILT_SO" ]]; then
  echo "ERROR: downloaded librknnrt.so is empty" >&2
  exit 1
fi
if [[ ! -s "$OVERLAY_BIN" ]]; then
  echo "ERROR: downloaded rknn_server is empty" >&2
  exit 1
fi

sync_rootfs_overlay
prebuilt_stamp "$ROOT/prebuilt/rknn-rt" "$VERSION"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
echo "fetch-rknn-rt: done (github)"
echo "  $PREBUILT_SO"
echo "  $PREBUILT_HEADER"
echo "  $OVERLAY_LIB"
echo "  $OVERLAY_BIN"
