#!/usr/bin/env bash
# Pack output/firmware/<sku>/factory.img from existing loader + dual FIT + rootfs + oem.
# Does NOT rebuild kernel or rootfs — run make build-kernel / build-rootfs / build-oem first.
# Migration: also refreshes output/firmware/update.img as a symlink to factory.img.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/factory-sku.sh
source "$ROOT/scripts/factory-sku.sh"

OUT_FIRMWARE="$ROOT/output/firmware"
UPDATE_IMG="$OUT_FIRMWARE/update.img"
PARAM="$ROOT/board/parameter-buildroot-fit.txt"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
LINUX_BOOT_MAX=$((64 * 1024 * 1024))

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Host output/firmware may hold broken symlinks from docker-export (SDK paths exist only in volume).
sanitize_host_firmware_dir() {
  local dir="$ROOT/output/firmware"
  local f
  mkdir -p "$dir"
  for f in "$dir"/*; do
    if [[ -L "$f" && ! -e "$f" ]]; then
      rm -f "$f"
    fi
  done
}

install_file() {
  local src="$1"
  local dest="$2"
  rm -f "$dest"
  cp -f "$src" "$dest"
}

install_file_follow() {
  local src="$1"
  local dest="$2"
  rm -f "$dest"
  cp -Lf "$src" "$dest"
}

publish_factory_artifacts() {
  local src_update="$1"
  mkdir -p "$FACTORY_OUT_DIR" "$OUT_FIRMWARE" "$ROOT/images/linux"
  install_file_follow "$src_update" "$FACTORY_IMG"
  # Migration: update.img → selected sku factory.img (symlink when possible).
  rm -f "$UPDATE_IMG"
  ln -sfn "$FACTORY_SKU/factory.img" "$UPDATE_IMG"
  # Real copy for Finder / cp -a convenience.
  rm -f "$ROOT/images/linux/update.img" "$ROOT/images/linux/factory.img"
  cp -fL "$FACTORY_IMG" "$ROOT/images/linux/factory.img"
  cp -fL "$FACTORY_IMG" "$ROOT/images/linux/update.img"
  if [[ -r "$FACTORY_OEM_IMG" ]]; then
    install_file_follow "$FACTORY_OEM_IMG" "$FACTORY_OUT_DIR/oem.img"
  fi
  install_file_follow "$FACTORY_UBOOT_IMG" "$FACTORY_OUT_DIR/uboot.img"
  install_file_follow "$FACTORY_LOADER_BIN" "$FACTORY_OUT_DIR/MiniLoaderAll.bin"
  {
    echo "factory_sku=$FACTORY_SKU"
    echo "uboot_id=$UBOOT_ID"
    echo "oem_id=$OEM_ID"
    echo "git_rev=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo "uboot=$FACTORY_UBOOT_IMG"
    echo "oem=$FACTORY_OEM_IMG"
    echo "factory_img=$FACTORY_IMG"
  } >"$FACTORY_OUT_DIR/manifest.txt"
  echo "factory.img ready: $FACTORY_IMG"
  bash "$SIZE_HELPER" "$FACTORY_IMG"
  echo "update.img symlink: $UPDATE_IMG -> $FACTORY_SKU/factory.img"
}

ensure_sdk_loader() {
  local sdk="$1" firmware="$2"
  local loader="$FACTORY_LOADER_BIN"
  local host="$ROOT/output/firmware/MiniLoaderAll.bin"

  factory_sku_require_uboot
  mkdir -p "$sdk/u-boot" "$firmware" "$ROOT/output/firmware"
  install_file_follow "$loader" "$firmware/MiniLoaderAll.bin"
  install_file_follow "$loader" "$sdk/u-boot/rk356x_spl_loader_v1.23.114.bin"
  install_file_follow "$loader" "$host"
  echo "MiniLoaderAll.bin: $UBOOT_ID"
  bash "$SIZE_HELPER" "$loader"
}

ensure_sdk_uboot() {
  local sdk="$1" firmware="$2"
  local vendor="$FACTORY_UBOOT_IMG"
  local dest="$firmware/uboot.img"
  local host="$ROOT/output/firmware/uboot.img"

  factory_sku_require_uboot
  mkdir -p "$firmware" "$ROOT/output/firmware"

  # ONLY unpatched vendor uboot. Do NOT binary-patch (env CRC → no backlight/maskrom).
  # Do NOT use LWS_HMI_COMPILED_UBOOT (ynh960 brick risk). Do NOT use Innohi uboot for Linux GPT.
  rm -f "$dest"
  install_file_follow "$vendor" "$dest"
  install_file_follow "$vendor" "$host"
  echo "uboot.img: $UBOOT_ID unmodified"
  bash "$SIZE_HELPER" "$vendor"
  echo "NOTE: bootcmd=boot_android;boot_fit — Linux needs Innohi uboot or serial 'boot_fit'"
  strings "$dest" | grep '^bootcmd=' || true
}

ensure_sdk_oem() {
  local firmware="$1"
  factory_sku_require_oem
  install_file_follow "$FACTORY_OEM_IMG" "$firmware/oem.img"
  install_file_follow "$FACTORY_OEM_IMG" "$OUT_FIRMWARE/oem.img"
  echo "oem.img: $OEM_ID"
  bash "$SIZE_HELPER" "$FACTORY_OEM_IMG"
}

install_misc() {
  local sdk="$1" firmware="$2"
  local dest="$firmware/misc.img"

  # 4 MiB misc: offset 0 zero (no Android boot-recovery BCB); LWS marker at
  # 1 MiB, clear of vendor U-Boot boot-control data at 2 KiB.
  # See docs/ab-slot-misc.md.
  rm -f "$dest"
  dd if=/dev/zero of="$dest" bs=4096 count=1024 status=none
  python3 - "$dest" <<'PY'
import struct, sys, zlib
path = sys.argv[1]
magic = b"LWSAB\x00\x01\x00"
# active=A, try=0, previous=A, tries=0
body = magic + bytes([ord("A"), 0, ord("A"), 0])
crc = zlib.crc32(body) & 0xffffffff
blob = body + struct.pack("<I", crc) + bytes(48)
with open(path, "r+b") as f:
    f.seek(1024 * 1024)
    f.write(blob[:64])
PY
  echo "misc.img: LWS A/B factory marker (active=A; no boot-recovery at offset 0)"
  bash "$SIZE_HELPER" "$dest"
}

pack_in_sdk() {
  local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
  local firmware="$sdk/output/firmware"
  local updateimg="$firmware/update.img"
  local boot_bytes rootfs_img

  factory_sku_print
  [[ -d "$sdk" ]] || die "SDK not found at $sdk"
  [[ -r "$sdk/output/.config" ]] || die "output/.config missing — run make lunch first"

  bash "$ROOT/scripts/apply-overlay.sh" >/dev/null
  bash "$ROOT/scripts/sync-lunch-config.sh"
  sanitize_host_firmware_dir

  rm -f "$firmware"/{vbmeta,dtbo,baseparameter}.img
  install_file "$PARAM" "$firmware/parameter.txt"
  ensure_sdk_loader "$sdk" "$firmware"
  ensure_sdk_uboot "$sdk" "$firmware"
  ensure_sdk_oem "$firmware"
  install_misc "$sdk" "$firmware"

  [[ -r "$firmware/boot.img" ]] || die "boot.img (rootfs_a FIT) missing — run make build-kernel (does not rebuild here)"
  [[ -r "$firmware/boot_b.img" ]] || die "boot_b.img (rootfs_b FIT) missing — run make build-kernel (does not rebuild here)"
  rootfs_img="$firmware/rootfs.img"
  [[ -r "$rootfs_img" ]] || rootfs_img="$(find "$sdk/buildroot/output" -name 'rootfs.ext2' -print -quit 2>/dev/null || true)"
  [[ -n "$rootfs_img" && -r "$rootfs_img" ]] \
    || die "rootfs missing — run make build-rootfs (does not rebuild here)"

  boot_bytes="$(wc -c <"$firmware/boot.img" | tr -d ' ')"
  echo "Firmware inputs:"
  bash "$SIZE_HELPER" "$firmware/boot.img" "$firmware/boot_b.img" "$rootfs_img" \
    "$firmware/MiniLoaderAll.bin" "$firmware/uboot.img" "$firmware/misc.img" "$firmware/oem.img"
  if [[ "$boot_bytes" -gt "$LINUX_BOOT_MAX" ]]; then
    die "boot.img is ${boot_bytes} bytes — Linux boot partition is 64 MiB"
  fi

  bash "$ROOT/scripts/verify-firmware-partitions.sh" "$firmware" "$PARAM"

  echo ""
  echo "Linux factory.img: SKU=$FACTORY_SKU loader+uboot+oem + hash-valid A/B FITs"
  echo "A/B GPT: boot←boot.img(rootfs_a), boot_b←boot_b.img(rootfs_b)"
  echo "Flash: FACTORY_SKU=$FACTORY_SKU make flash; later: make upgrade (SSH, boot+rootfs+oem)"
  echo "Note: PARTNAME=boot required (vendor U-Boot); not boot_a — see docs/ab-slot-misc.md"
  echo ""

  cd "$sdk"
  ./build.sh updateimg

  [[ -r "$updateimg" ]] || die "pack failed: $updateimg"
  publish_factory_artifacts "$updateimg"
}

if [[ "${LWS_HMI_PACK_IMG:-}" == "1" ]]; then
  pack_in_sdk
  exit 0
fi

export LWS_HMI_PACK_IMG=1
bash "$ROOT/scripts/docker-run.sh" \
  env LWS_HMI_PACK_IMG=1 FACTORY_SKU="$FACTORY_SKU" UBOOT_ID="$UBOOT_ID" OEM_ID="$OEM_ID" \
  bash /work/lws-hmi/scripts/build-img.sh

bash "$ROOT/scripts/docker-export-artifacts.sh" update

if [[ -r "$FACTORY_IMG" || -r "$UPDATE_IMG" ]]; then
  if [[ -r "$FACTORY_IMG" ]]; then
    rm -f "$UPDATE_IMG"
    ln -sfn "$FACTORY_SKU/factory.img" "$UPDATE_IMG"
  elif [[ -r "$UPDATE_IMG" && ! -e "$FACTORY_IMG" ]]; then
    mkdir -p "$FACTORY_OUT_DIR"
    cp -fL "$UPDATE_IMG" "$FACTORY_IMG"
    rm -f "$UPDATE_IMG"
    ln -sfn "$FACTORY_SKU/factory.img" "$UPDATE_IMG"
  fi
  echo ""
  echo "Host firmware ready:"
  bash "$SIZE_HELPER" "$FACTORY_IMG" 2>/dev/null || bash "$SIZE_HELPER" "$UPDATE_IMG"
else
  die "factory.img / update.img missing after build-img + export"
fi
