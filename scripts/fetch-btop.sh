#!/usr/bin/env bash
# Fetch official btop aarch64 musl static binary → prebuilt/ + rootfs-overlay.
# GCC 10.3 product toolchain cannot build modern btop from source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/btop.version"
SRC_ROOT="$ROOT/.cache/btop"
OUT_DIR="$ROOT/prebuilt/btop/aarch64"
OVERLAY_BIN="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/bin/btop"
FORCE="${FORCE:-0}"

read_tag() {
  if [[ -n "${BTOP_VERSION:-}" ]]; then
    echo "$BTOP_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" "v1.4.7"
}

TAG="$(read_tag)"
ASSET="btop-aarch64-unknown-linux-musl.tar.gz"
RELEASE_URL="https://github.com/aristocratos/btop/releases/download/${TAG}/${ASSET}"
CACHE_TAR="$SRC_ROOT/${TAG}-${ASSET}"

sync_rootfs_overlay() {
  if [[ -x "$OUT_DIR/btop" ]]; then
    mkdir -p "$(dirname "$OVERLAY_BIN")"
    install -m 0755 "$OUT_DIR/btop" "$OVERLAY_BIN"
    echo "fetch-btop: synced → $OVERLAY_BIN"
  fi
}

if prebuilt_ready "$OUT_DIR" && [[ -x "$OUT_DIR/btop" && -x "$OVERLAY_BIN" ]] && \
   [[ "$FORCE" != "1" ]]; then
  echo "fetch-btop: prebuilt ready at $OUT_DIR"
  sync_rootfs_overlay
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$OUT_DIR" "$CACHE_TAR"
  rm -f "$OVERLAY_BIN"
fi

mkdir -p "$SRC_ROOT" "$OUT_DIR"

if [[ -f "$CACHE_TAR" ]]; then
  echo "fetch-btop: using cached $CACHE_TAR"
else
  echo "fetch-btop: downloading ${RELEASE_URL} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$CACHE_TAR" "$RELEASE_URL"
fi

EXTRACT_DIR="$SRC_ROOT/extract-${TAG}"
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
tar -xzf "$CACHE_TAR" -C "$EXTRACT_DIR"

BTOP_SRC=""
if [[ -x "$EXTRACT_DIR/bin/btop" ]]; then
  BTOP_SRC="$EXTRACT_DIR/bin/btop"
elif [[ -x "$EXTRACT_DIR/btop/bin/btop" ]]; then
  BTOP_SRC="$EXTRACT_DIR/btop/bin/btop"
else
  BTOP_SRC="$(find "$EXTRACT_DIR" -type f -name btop -perm -111 2>/dev/null | head -1 || true)"
fi

if [[ -z "$BTOP_SRC" || ! -x "$BTOP_SRC" ]]; then
  echo "ERROR: btop binary missing after extract of $CACHE_TAR" >&2
  exit 1
fi

install -m 0755 "$BTOP_SRC" "$OUT_DIR/btop"
prebuilt_stamp "$OUT_DIR" "${TAG}-aarch64-musl"
sync_rootfs_overlay
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
echo "fetch-btop: done → $OUT_DIR/btop (${TAG})"
