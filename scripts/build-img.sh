#!/usr/bin/env bash
# Pack output/firmware/update.img — SDK ynh960 Linux (compiled uboot + zero misc).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FIRMWARE="$ROOT/output/firmware"
UPDATE_IMG="$OUT_FIRMWARE/update.img"
PARAM="$ROOT/board/parameter-buildroot-fit.txt"
LINUX_BOOT_MAX=$((64 * 1024 * 1024))

die() {
  echo "ERROR: $*" >&2
  exit 1
}

install_update_img() {
  local src="$1"
  cp -f "$src" "$UPDATE_IMG"
  ls -lh "$UPDATE_IMG"
  echo "update.img ready: $UPDATE_IMG"
}

link_parameter() {
  local sdk="$1" firmware="$2"
  if [[ -r "$firmware/parameter.txt" ]]; then
    return 0
  fi
  local parameter
  parameter="$(sed -n 's/^RK_PARAMETER="\(.*\)"$/\1/p' "$sdk/output/.config")"
  [[ -n "$parameter" ]] || die "RK_PARAMETER missing in output/.config"
  for param in \
    "$sdk/device/rockchip/.chips/rk3566_rk3568/$parameter" \
    "$sdk/device/rockchip/rk3566_rk3568/$parameter" \
    "$PARAM"; do
    if [[ -r "$param" ]]; then
      cp -f "$param" "$firmware/parameter.txt"
      return 0
    fi
  done
  die "parameter file not found: $parameter"
}

ensure_sdk_loader() {
  local sdk="$1" firmware="$2"
  local loader="$ROOT/prebuilt/sdk-loader/MiniLoaderAll.bin"
  local host="$ROOT/output/firmware/MiniLoaderAll.bin"

  [[ -r "$loader" ]] || die "missing $loader (copy SDK MiniLoaderAll.bin into prebuilt/sdk-loader/)"
  mkdir -p "$sdk/u-boot" "$firmware" "$ROOT/output/firmware"
  cp -f "$loader" "$firmware/MiniLoaderAll.bin"
  cp -f "$loader" "$sdk/u-boot/rk356x_spl_loader_v1.23.114.bin"
  cp -f "$loader" "$host"
  echo "MiniLoaderAll.bin: SDK prebuilt ($(wc -c <"$loader" | tr -d ' ') bytes — never use compiled loader)"
}

ensure_sdk_uboot() {
  local sdk="$1" firmware="$2"
  local vendor="$ROOT/prebuilt/sdk-uboot/uboot.img"
  local dest="$firmware/uboot.img"
  local host="$ROOT/output/firmware/uboot.img"

  [[ -r "$vendor" ]] || die "missing $vendor"
  mkdir -p "$firmware" "$ROOT/output/firmware"

  # ONLY unpatched vendor uboot. Do NOT binary-patch (env CRC → no backlight/maskrom).
  # Do NOT use LWS_HMI_COMPILED_UBOOT (ynh960 brick risk). Do NOT use MuJia uboot for Linux GPT.
  rm -f "$dest"
  cp -f "$vendor" "$dest"
  cp -f "$vendor" "$host"
  echo "uboot.img: vendor SDK unmodified ($(wc -c <"$vendor" | tr -d ' ') bytes)"
  echo "NOTE: bootcmd=boot_android;boot_fit — Linux needs Innohi uboot or serial 'boot_fit'"
  strings "$dest" | grep '^bootcmd=' || true
}

install_misc() {
  local sdk="$1" firmware="$2"
  local dest="$firmware/misc.img"
  local zero_misc="$firmware/misc-lws-zero.img"
  local sdk_misc="$sdk/output/misc.img"

  rm -f "$dest"
  if [[ -r "$zero_misc" ]]; then
    cp -f "$zero_misc" "$dest"
  elif [[ -r "$sdk_misc" ]]; then
    cp -fL "$sdk_misc" "$dest" 2>/dev/null || cp -f "$sdk_misc" "$dest"
  else
    dd if=/dev/zero of="$dest" bs=4096 count=1024 status=none
  fi
  echo "misc.img: cleared (no boot-recovery — MuJia misc breaks Linux boot)"
}

pack_in_sdk() {
  local sdk="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
  local firmware="$sdk/output/firmware"
  local updateimg="$firmware/update.img"
  local boot_bytes

  [[ -d "$sdk" ]] || die "SDK not found — run: make link-sdk"
  [[ -r "$sdk/output/.config" ]] || die "output/.config missing — run make lunch first"

  bash "$ROOT/scripts/apply-overlay.sh" >/dev/null
  bash "$ROOT/scripts/sync-lunch-config.sh"

  rm -f "$firmware"/{vbmeta,dtbo,baseparameter}.img
  cp -f "$PARAM" "$firmware/parameter.txt"
  ensure_sdk_loader "$sdk" "$firmware"
  ensure_sdk_uboot "$sdk" "$firmware"
  install_misc "$sdk" "$firmware"

  [[ -r "$firmware/boot.img" ]] || die "boot.img missing — run make build-kernel"
  [[ -r "$firmware/rootfs.img" || -n "$(find "$sdk/buildroot/output" -name 'rootfs.ext2' -print -quit 2>/dev/null)" ]] \
    || die "rootfs missing — run make build-rootfs"

  boot_bytes="$(wc -c <"$firmware/boot.img" | tr -d ' ')"
  echo "boot.img: $boot_bytes bytes"
  if [[ "$boot_bytes" -gt "$LINUX_BOOT_MAX" ]]; then
    die "boot.img is ${boot_bytes} bytes — Linux boot partition is 64 MiB"
  fi

  bash "$ROOT/scripts/verify-firmware-partitions.sh" "$firmware" "$PARAM"

  echo ""
  echo "Linux update.img: SDK loader + vendor uboot (unmodified) + ynh960 FIT boot.img"
  echo "Flash: make flash"
  echo ""

  cd "$sdk"
  ./build.sh updateimg

  [[ -r "$updateimg" ]] || die "pack failed: $updateimg"
  install_update_img "$updateimg"
}

if [[ "${LWS_HMI_PACK_IMG:-}" == "1" ]]; then
  pack_in_sdk
  exit 0
fi

export LWS_HMI_PACK_IMG=1
bash "$ROOT/scripts/docker-run.sh" \
  bash -c 'export LWS_HMI_PACK_IMG=1; bash /work/lws-hmi/scripts/build-img.sh'

if [[ -r "$UPDATE_IMG" ]]; then
  echo ""
  ls -lh "$UPDATE_IMG"
fi
