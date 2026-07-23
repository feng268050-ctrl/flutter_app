#!/usr/bin/env bash
# Fetch Rockchip MPP public headers for StreamDetect cross-compile.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ABI="${ANDROID_ABI:-arm64-v8a}"
DEST="$ROOT/native/toolchains/rockchip-mpp/$ABI"
INCLUDE_DIR="$DEST/include"
TMP="${TMPDIR:-/tmp}/lws-mpp-fetch"

MPP_REF="${ROCKCHIP_MPP_REF:-develop}"
MPP_REPO="${ROCKCHIP_MPP_REPO:-https://github.com/rockchip-linux/mpp.git}"

mkdir -p "$INCLUDE_DIR" "$DEST/lib"

if [[ -f "$INCLUDE_DIR/rk_mpi.h" ]]; then
  echo "fetch-rockchip-mpp: headers already present at $INCLUDE_DIR"
  exit 0
fi

rm -rf "$TMP"
git clone --depth 1 --branch "$MPP_REF" "$MPP_REPO" "$TMP"

cp -R "$TMP/inc/." "$INCLUDE_DIR/"
rm -rf "$TMP"

echo "fetch-rockchip-mpp: installed headers to $INCLUDE_DIR"
echo "fetch-rockchip-mpp: next pull device lib:"
echo "  adb pull /vendor/lib64/libmpp.so $DEST/lib/libmpp.so"
