#!/usr/bin/env bash
# Assemble OEM pack into ext4 oem/out/<oem_id>/oem.img
# Usage: FACTORY_SKU=ynh960-p800 make build-oem
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/factory-sku.sh
source "$ROOT/scripts/factory-sku.sh"

OEM_SRC="$ROOT/oem"
PACK_DIR="$OEM_SRC/packs/$OEM_ID"
# GPT oem partition is 128 MiB; keep image smaller but roomy for helpers later.
OEM_IMG_BYTES=$((32 * 1024 * 1024))

die() {
  echo "ERROR: $*" >&2
  exit 1
}

factory_sku_print
[[ -d "$PACK_DIR" ]] || die "OEM pack missing: $PACK_DIR"
[[ -r "$PACK_DIR/manifest.json" ]] || die "missing $PACK_DIR/manifest.json"

# macOS host: mkfs.ext4/loop need Linux — run the whole script in Docker once.
if [[ "$(uname -s)" == Darwin && "${LWS_HMI_BUILD_OEM:-}" != "1" ]]; then
  bash "$ROOT/scripts/docker-run.sh" \
    env LWS_HMI_BUILD_OEM=1 FACTORY_SKU="$FACTORY_SKU" UBOOT_ID="$UBOOT_ID" OEM_ID="$OEM_ID" \
    bash /work/lws-hmi/scripts/build-oem.sh
  [[ -r "$FACTORY_OEM_IMG" ]] || die "oem.img missing after Docker build: $FACTORY_OEM_IMG"
  echo "oem.img ready: $FACTORY_OEM_IMG"
  bash "$ROOT/scripts/artifact-size.sh" "$FACTORY_OEM_IMG"
  exit 0
fi

board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
screen_path="$(sed -n 's/.*"screen_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
[[ -n "$board_path" && -n "$screen_path" ]] || die "manifest missing board_path/screen_path"
[[ -d "$OEM_SRC/$board_path" ]] || die "board path missing: $OEM_SRC/$board_path"
[[ -d "$OEM_SRC/$screen_path" ]] || die "screen path missing: $OEM_SRC/$screen_path"

STAGE="$(mktemp -d /tmp/lws-hmi-oem-stage.XXXXXX)"
cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$STAGE/$board_path" "$STAGE/$screen_path"
cp -f "$PACK_DIR/manifest.json" "$STAGE/manifest.json"
cp -a "$OEM_SRC/$board_path"/. "$STAGE/$board_path"/
cp -a "$OEM_SRC/$screen_path"/. "$STAGE/$screen_path"/

mkdir -p "$FACTORY_OEM_OUT_DIR"
OUT="$FACTORY_OEM_IMG"
rm -f "$OUT"
truncate -s "$OEM_IMG_BYTES" "$OUT"
mkfs.ext4 -F -L oem "$OUT" >/dev/null
MNT="$(mktemp -d /tmp/lws-oem-mnt.XXXXXX)"
mount -o loop "$OUT" "$MNT"
cp -a "$STAGE"/. "$MNT"/
sync
umount "$MNT"
rmdir "$MNT"

[[ -r "$OUT" ]] || die "oem.img missing after build: $OUT"
echo "oem.img ready: $OUT ($(wc -c <"$OUT" | tr -d ' ') bytes)"
bash "$ROOT/scripts/artifact-size.sh" "$OUT"
