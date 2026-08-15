#!/usr/bin/env bash
# Build U-Boot from source with Linux-first bootcmd (ynh960 / Buildroot GPT).
# Packs TRUST from SDK RK3568TRUST.ini (BL31 v1.44 / BL32 v2.15).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

verify_linux_first_uboot() {
  local elf="$1"
  local cmd
  [[ -r "$elf" ]] || { echo "ERROR: missing $elf for bootcmd verify" >&2; return 1; }
  cmd="$(strings -a "$elf" | grep '^bootcmd=' | head -1 || true)"
  echo "verify: $cmd"
  if [[ -z "$cmd" ]]; then
    echo "ERROR: no bootcmd= string in $elf" >&2
    return 1
  fi
  # Android try must not precede boot_fit in the default bootcmd value.
  if [[ "$cmd" == *boot_android* && "$cmd" == *boot_fit* ]]; then
    local before="${cmd%%boot_fit*}"
    if [[ "$before" == *boot_android* ]]; then
      echo "ERROR: boot_android appears before boot_fit in default bootcmd" >&2
      return 1
    fi
  fi
  if [[ "$cmd" != *boot_fit* ]]; then
    echo "ERROR: bootcmd missing boot_fit" >&2
    return 1
  fi
  strings -a "$elf" | grep -E 'bl31-v1\.44|bl32-v2\.15' >/dev/null 2>&1 || true
  echo "OK: Linux-first bootcmd"
}

if [[ "${BUILD_UBOOT:-}" == "1" ]]; then
  SDK="${SDK_DIR:-$ROOT/linux-sdk}"
  [[ -d "$SDK" ]] || { echo "ERROR: SDK missing" >&2; exit 1; }

  bash "$ROOT/scripts/apply-overlay.sh" >/dev/null
  bash "$ROOT/scripts/fetch-uboot.sh"
  bash "$ROOT/scripts/sync-lunch-config.sh"

  UBOOT_DIR="$SDK/u-boot"
  CROSS="$SDK/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-"
  [[ -x "${CROSS}gcc" ]] || { echo "ERROR: missing CROSS_COMPILE at $CROSS" >&2; exit 1; }

  # ./build.sh uboot often no-ops when uboot.img already exists — build via make.sh.
  cd "$UBOOT_DIR"
  bash "$ROOT/overlay/device/rockchip/common/scripts/patch-uboot-bootcmd.sh" \
    "$UBOOT_DIR/include/configs/rockchip-common.h"
  rm -f uboot.img
  if [[ "${FORCE_UBOOT_CLEAN:-0}" == "1" ]]; then
    make distclean >/dev/null 2>&1 || true
  fi
  ./make.sh rk3566_rk3568 CROSS_COMPILE="$CROSS"

  uboot="$UBOOT_DIR/uboot.img"
  [[ -r "$uboot" ]] || { echo "ERROR: build produced no uboot.img" >&2; exit 1; }
  verify_linux_first_uboot "$UBOOT_DIR/u-boot"

  mkdir -p "$ROOT/output/firmware"
  cp -f "$uboot" "$ROOT/output/firmware/uboot.img"
  echo "WARNING: make.sh may also emit *_spl_loader_*.bin here — install SPL from rkbin boot_merger + RK3566MINIALL.ini into prebuilt/bootloader/<uboot_id>/ (docs/uboot-rkbin.md)" >&2

  echo "uboot.img: $(wc -c <"$uboot" | tr -d ' ') bytes (self-built Linux-first)"
  strings -a "$UBOOT_DIR/u-boot" | grep '^bootcmd=' || true
  # TRUST pins live in packed FIT (gzip); confirm from rkbin bins used by TRUST.ini
  strings -a "$SDK/rkbin/bin/rk35/rk3568_bl31_v1.44.elf" | grep 'bl31-v' | head -1 || true
  strings -a "$SDK/rkbin/bin/rk35/rk3568_bl32_v2.15.bin" | grep 'bl32-v' | head -1 || true

  if [[ "${INSTALL_UBOOT_PREBUILT:-0}" == "1" ]]; then
    dest_dir="$ROOT/prebuilt/bootloader/${UBOOT_ID:-rockchip-ynh960}"
    mkdir -p "$dest_dir"
    cp -f "$uboot" "$dest_dir/uboot.img"
    echo "installed: $dest_dir/uboot.img"
  fi
  exit 0
fi

export BUILD_UBOOT=1
bash "$ROOT/scripts/docker-run.sh" \
  bash -c 'export BUILD_UBOOT=1 FORCE_UBOOT_CLEAN="${FORCE_UBOOT_CLEAN:-0}" INSTALL_UBOOT_PREBUILT="${INSTALL_UBOOT_PREBUILT:-0}" UBOOT_ID="${UBOOT_ID:-rockchip-ynh960}"; bash /work/lws-hmi/scripts/build-uboot.sh'
