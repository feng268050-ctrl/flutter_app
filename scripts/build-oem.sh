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

factory_sku_print_oem
[[ -d "$PACK_DIR" ]] || die "OEM pack missing: $PACK_DIR"
[[ -r "$PACK_DIR/manifest.json" ]] || die "missing $PACK_DIR/manifest.json"

# macOS host: mkfs.ext4/loop need Linux — run the whole script in Docker once.
if [[ "$(uname -s)" == Darwin && "${BUILD_OEM:-}" != "1" ]]; then
  bash "$ROOT/scripts/docker-run.sh" \
    env BUILD_OEM=1 FACTORY_SKU="$FACTORY_SKU" UBOOT_ID="$UBOOT_ID" OEM_ID="$OEM_ID" \
    bash /work/lws-hmi/scripts/build-oem.sh
  [[ -r "$FACTORY_OEM_IMG" ]] || die "oem.img missing after Docker build: $FACTORY_OEM_IMG"
  echo "oem.img ready: $FACTORY_OEM_IMG"
  bash "$ROOT/scripts/artifact-size.sh" "$FACTORY_OEM_IMG"
  exit 0
fi

board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
screen_path="$(sed -n 's/.*"screen_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
board_id="$(sed -n 's/.*"board_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
soc_family="$(sed -n 's/.*"soc_family"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PACK_DIR/manifest.json" | head -1)"
[[ -n "$board_path" && -n "$screen_path" ]] || die "manifest missing board_path/screen_path"
[[ -d "$OEM_SRC/$board_path" ]] || die "board path missing: $OEM_SRC/$board_path"
[[ -d "$OEM_SRC/$screen_path" ]] || die "screen path missing: $OEM_SRC/$screen_path"

# W5: product OEM board_id must match a FIT conf in the SoC-family inventory.
# Emulator/virt packs are exempt (bare Image + QEMU DT — not product FIT).
INVENTORY="$ROOT/board/rk356x-fit-boards.txt"
if [[ -n "$board_id" && "$soc_family" != "virt" && -r "$INVENTORY" ]]; then
  if ! awk -v id="$board_id" '
    {
      sub(/#.*/, "");
      gsub(/^[[:space:]]+|[[:space:]]+$/, "");
      if ($0 == id) found=1
    }
    END { exit found ? 0 : 1 }
  ' "$INVENTORY"; then
    die "OEM board_id='$board_id' not in FIT inventory $INVENTORY (must equal FIT conf name; no startup DTB under oem/)"
  fi
  if find "$OEM_SRC/$board_path" "$OEM_SRC/$screen_path" -type f \( -name '*.dtb' -o -name '*.dtbo' \) 2>/dev/null | grep -q .; then
    die "OEM pack must not ship startup DTB/DTBO under board/screen paths (DT lives in boot FIT)"
  fi
  echo "OEM board_id=$board_id aligns with FIT inventory"
fi

STAGE="$(mktemp -d /tmp/lws-hmi-oem-stage.XXXXXX)"
cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$STAGE/$board_path" "$STAGE/$screen_path"
cp -f "$PACK_DIR/manifest.json" "$STAGE/manifest.json"
cp -a "$OEM_SRC/$board_path"/. "$STAGE/$board_path"/
cp -a "$OEM_SRC/$screen_path"/. "$STAGE/$screen_path"/

# Board radio pack (optional): firmware keep-set under radio/firmware/ is copied
# with the board path above. Fail closed if a manifest exists without blobs.
radio_fw="$STAGE/$board_path/radio/firmware"
radio_manifest="$STAGE/$board_path/radio/manifest.json"
if [[ -f "$radio_manifest" ]]; then
  [[ -d "$radio_fw" ]] || die "radio/manifest.json present but missing $board_path/radio/firmware/"
  if ! compgen -G "$radio_fw/*" >/dev/null 2>&1; then
    die "radio/firmware/ is empty under $board_path (pack keep-set required)"
  fi
  if find "$STAGE/$board_path/radio" -type f -name '*.ko' 2>/dev/null | grep -q .; then
    die "OEM radio pack must not ship kernel modules (*.ko) under radio/"
  fi
  echo "OEM radio pack: $board_path/radio ($(du -sh "$radio_fw" | awk '{print $1}'))"
fi

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
