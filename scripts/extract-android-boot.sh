#!/usr/bin/env bash
# Extract MuJia/Android boot chain (MiniLoaderAll + uboot) for hybrid Linux images.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE_TOOL="$ROOT/tools/upgrade_tool/upgrade_tool"
ANDROID_IMG="${ANDROID_UPDATE_IMG:-$ROOT/images/android/update.img}"
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
echo "Extracting Android boot chain from: $ANDROID_IMG"
( cd "$ROOT/tools/upgrade_tool" && ./upgrade_tool EXF "$ANDROID_IMG" "$TMP_DIR" >/dev/null )

for f in MiniLoaderAll.bin uboot.img; do
  src="$TMP_DIR/$f"
  [[ -r "$src" ]] || die "extract missing $f"
  cp -f "$src" "$OUT_DIR/$f"
done

ls -lh "$OUT_DIR"/MiniLoaderAll.bin "$OUT_DIR"/uboot.img
echo "Android boot chain ready: $OUT_DIR"
