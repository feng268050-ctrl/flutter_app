#!/usr/bin/env bash
# Select ynh960 boot chain before packing update.img:
#   sdk    — Rockchip SDK loader + uboot (default; SDK demo Linux GPT)
#   innohi — Innohi MiniLoader + uboot (Android hardware path; use with Android GPT only)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"

FIRMWARE="$SDK/output/firmware"
ANDROID_BOOT="$ROOT/output/firmware/android-boot"
CHAIN="${LWS_HMI_BOOT_CHAIN:-sdk}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

ensure_android_boot() {
  if [[ -r "$ANDROID_BOOT/MiniLoaderAll.bin" && -r "$ANDROID_BOOT/uboot.img" ]]; then
    return 0
  fi
  bash "$ROOT/scripts/extract-android-boot.sh"
  [[ -r "$ANDROID_BOOT/MiniLoaderAll.bin" && -r "$ANDROID_BOOT/uboot.img" ]] \
    || die "Android boot chain missing — set ANDROID_UPDATE_IMG or run extract-android-boot.sh"
}

install_innohi_boot() {
  local patched="$FIRMWARE/uboot-lws.img"
  ensure_android_boot
  cp -f "$ANDROID_BOOT/MiniLoaderAll.bin" "$FIRMWARE/MiniLoaderAll.bin"
  bash "$ROOT/scripts/patch-uboot-bootcmd.sh" "$ANDROID_BOOT/uboot.img" "$patched"
  rm -f "$FIRMWARE/uboot.img"
  cp -f "$patched" "$FIRMWARE/uboot.img"
  echo "Boot chain: Innohi loader+uboot (bootcmd=boot_fit)"
}

install_sdk_boot() {
  local patched="$FIRMWARE/uboot-lws.img"
  local uboot_src
  bash "$ROOT/scripts/restore-sdk-loader.sh"
  uboot_src="$(readlink -f "$FIRMWARE/uboot.img" 2>/dev/null || realpath "$FIRMWARE/uboot.img")"
  bash "$ROOT/scripts/patch-uboot-bootcmd.sh" "$uboot_src" "$patched"
  rm -f "$FIRMWARE/uboot.img"
  cp -f "$patched" "$FIRMWARE/uboot.img"
  echo "Boot chain: SDK loader+uboot (generic RK3568)"
}

ensure_clean_misc() {
  # Slice flash must not overwrite Android misc (may hold boot-critical env).
  echo "misc.img: unchanged (slice flash preserves Android misc)"
}

[[ -d "$FIRMWARE" ]] || die "firmware dir missing: $FIRMWARE"

case "$CHAIN" in
  innohi) install_innohi_boot ;;
  sdk) install_sdk_boot ;;
  *) die "unknown LWS_HMI_BOOT_CHAIN=$CHAIN (innohi|sdk)" ;;
esac

ensure_clean_misc
