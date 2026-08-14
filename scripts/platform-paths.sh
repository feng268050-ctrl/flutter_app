#!/usr/bin/env bash
# Rockchip SDK platform layout paths — source after ROOT (+ optional SDK) are set.
#
# LWS_CHIP / CHIP = SoC platform id for `make lunch` (default rk3566_rk3568).
# Not product selection (use APP=) and not factory hardware (use OEM / FACTORY_SKU).
#
# Overlay layout:
#   overlay/board/rockchip/common/     — generic OS (rootfs-overlay + post-build hooks)
#   overlay/board/rockchip/$CHIP/      — SoC-thin extras (e.g. Innohi MainServer)
#
# Usage:
#   platform_paths_init "$ROOT" "$SDK"
set -euo pipefail

platform_paths_init() {
  local root="${1:?platform_paths_init: root required}"
  local sdk="${2:?platform_paths_init: sdk required}"

  LWS_CHIP="${CHIP:-rk3566_rk3568}"
  LWS_BOARD_VENDOR="${LWS_BOARD_VENDOR:-rockchip}"

  LWS_ROOT="$root"
  LWS_SDK="$sdk"

  OVERLAY_COMMON="$root/overlay/board/$LWS_BOARD_VENDOR/common"
  OVERLAY_FS="$OVERLAY_COMMON/rootfs-overlay"
  LWS_OVERLAY_BOARD="$OVERLAY_COMMON"

  OVERLAY_CHIP="$root/overlay/board/$LWS_BOARD_VENDOR/$LWS_CHIP"
  OVERLAY_CHIP_FS="$OVERLAY_CHIP/rootfs-overlay"

  CHIP_DIR="$sdk/device/$LWS_BOARD_VENDOR/$LWS_CHIP"
  CHIPS_DIR="$sdk/device/$LWS_BOARD_VENDOR/.chips/$LWS_CHIP"
  SCRIPTS_DIR="$sdk/device/$LWS_BOARD_VENDOR/common/scripts"
  POST_HOOKS_DIR="$sdk/device/$LWS_BOARD_VENDOR/common/post-hooks"
  HOOKS_DIR="$sdk/device/$LWS_BOARD_VENDOR/common/build-hooks"

  BR_COMMON="$sdk/buildroot/board/$LWS_BOARD_VENDOR/common"
  BR_OVERLAY_ROOT="$BR_COMMON/rootfs-overlay"
  BR_BOARD="$sdk/buildroot/board/$LWS_BOARD_VENDOR/$LWS_CHIP"
  BR_CHIP_OVERLAY_ROOT="$BR_BOARD/rootfs-overlay"
  # Innohi LCD param dest (chip overlay /system/etc), not generic OS.
  BR_OVERLAY="$BR_CHIP_OVERLAY_ROOT/system/etc"

  BR_CONFIG="$sdk/buildroot/configs/rockchip/chips/${LWS_CHIP}.config"
  BR_CHIPS_DIR="$sdk/buildroot/configs/rockchip/chips"

  LWS_BR_BASE_CFG="${LWS_CHIP}_lws_hmi"
  LWS_BR_DEFCONFIG="$root/overlay/buildroot/rockchip_${LWS_BR_BASE_CFG}_defconfig"
  LWS_BR_DEFCONFIG_GEN="$root/overlay/buildroot/.generated/rockchip_${LWS_BR_BASE_CFG}_defconfig"

  export LWS_CHIP LWS_BOARD_VENDOR LWS_ROOT LWS_SDK
  export OVERLAY_COMMON OVERLAY_FS LWS_OVERLAY_BOARD OVERLAY_CHIP OVERLAY_CHIP_FS
  export CHIP_DIR CHIPS_DIR SCRIPTS_DIR POST_HOOKS_DIR HOOKS_DIR
  export BR_COMMON BR_OVERLAY_ROOT BR_BOARD BR_CHIP_OVERLAY_ROOT BR_OVERLAY
  export BR_CONFIG BR_CHIPS_DIR
  export LWS_BR_BASE_CFG LWS_BR_DEFCONFIG LWS_BR_DEFCONFIG_GEN
}

# Resolve generic OS helper: prefer SDK common/lws-hmi copy after apply-overlay.
platform_paths_board_script() {
  local name="$1"
  if [[ -x "$BR_COMMON/lws-hmi/$name" ]]; then
    printf '%s\n' "$BR_COMMON/lws-hmi/$name"
  elif [[ -f "$OVERLAY_COMMON/$name" ]]; then
    printf '%s\n' "$OVERLAY_COMMON/$name"
  else
    return 1
  fi
}
