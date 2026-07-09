#!/usr/bin/env bash
# Extract MuJia Android images needed for ynh960 slice flash (no parameter/loader).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE_TOOL="$ROOT/tools/upgrade_tool/upgrade_tool"
ANDROID_IMG="${ANDROID_UPDATE_IMG:-$HOME/Downloads/MuJia_960_rk356x_11.0_20260617_1047.img}"
OUT_DIR="$ROOT/output/firmware/android-boot"
TMP_DIR="$(mktemp -d)"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[[ -r "$ANDROID_IMG" ]] || die "Android firmware not found: $ANDROID_IMG"
[[ -x "$UPGRADE_TOOL" ]] || die "upgrade_tool missing: $UPGRADE_TOOL"

mkdir -p "$OUT_DIR"
echo "Extracting Android firmware from: $ANDROID_IMG"
( cd "$ROOT/tools/upgrade_tool" && ./upgrade_tool EXF "$ANDROID_IMG" "$TMP_DIR" >/dev/null )

copy_one() {
  local name="$1"
  local src="$TMP_DIR/$name"
  [[ -r "$src" ]] || src="$TMP_DIR/Image/$name"
  [[ -r "$src" ]] || die "extract missing $name"
  cp -f "$src" "$OUT_DIR/$name"
}

for f in MiniLoaderAll.bin uboot.img vbmeta.img dtbo.img baseparameter.img parameter.txt; do
  copy_one "$f"
done

# Prebuilt fallbacks for Docker builds (no access to ~/Downloads).
mkdir -p "$ROOT/prebuilt/android-vbmeta" "$ROOT/prebuilt/android-dtbo" \
  "$ROOT/prebuilt/android-baseparameter" "$ROOT/prebuilt/android-parameter"
cp -f "$OUT_DIR/vbmeta.img" "$ROOT/prebuilt/android-vbmeta/vbmeta.img"
cp -f "$OUT_DIR/dtbo.img" "$ROOT/prebuilt/android-dtbo/dtbo.img"
cp -f "$OUT_DIR/baseparameter.img" "$ROOT/prebuilt/android-baseparameter/baseparameter.img"
cp -f "$OUT_DIR/parameter.txt" "$ROOT/prebuilt/android-parameter/parameter.txt"

ls -lh "$OUT_DIR"/MiniLoaderAll.bin "$OUT_DIR"/uboot.img "$OUT_DIR"/parameter.txt \
  "$OUT_DIR"/vbmeta.img "$OUT_DIR"/dtbo.img "$OUT_DIR"/baseparameter.img
echo "Android firmware extract ready: $OUT_DIR"
