#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/sdk}"
BOARD_DIR="$ROOT/board"
OVERLAY="$ROOT/overlay"

if [[ ! -d "$SDK" ]]; then
  echo "ERROR: SDK symlink missing. Run: make link-sdk" >&2
  exit 1
fi

CHIP_DIR="$SDK/device/rockchip/rk3566_rk3568"
CHIPS_DIR="$SDK/device/rockchip/.chips/rk3566_rk3568"
SCRIPTS_DIR="$SDK/device/rockchip/common/scripts"
POST_HOOKS_DIR="$SDK/device/rockchip/common/post-hooks"
BR_CONFIG="$SDK/buildroot/configs/rockchip/chips/rk3566_rk3568.config"
BR_CHIPS_DIR="$SDK/buildroot/configs/rockchip/chips"
BR_DEFCONFIGS="$SDK/buildroot/configs"
BR_OVERLAY_ROOT="$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay"
BR_OVERLAY="$BR_OVERLAY_ROOT/system/etc"
OVERLAY_FS="$OVERLAY/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay"

install_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  echo "overlay: $dst"
}

sync_fs_overlay() {
  if [[ ! -d "$OVERLAY_FS" ]]; then
    echo "WARNING: $OVERLAY_FS missing; skip fs-overlay sync" >&2
    return 0
  fi
  mkdir -p "$BR_OVERLAY_ROOT"
  # Plan A systemd units + journald; keep system/etc from sync_display_params.
  if [[ -d "$OVERLAY_FS/etc" ]]; then
    mkdir -p "$BR_OVERLAY_ROOT/etc"
    cp -a "$OVERLAY_FS/etc/." "$BR_OVERLAY_ROOT/etc/"
    echo "overlay: synced $BR_OVERLAY_ROOT/etc"
  fi
}

sync_buildroot_chip_configs() {
  local src_dir="$OVERLAY/buildroot/chips"
  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi
  mkdir -p "$BR_CHIPS_DIR"
  for f in "$src_dir"/*.config; do
    [[ -f "$f" ]] || continue
    install_file "$f" "$BR_CHIPS_DIR/$(basename "$f")"
  done
  local def="$OVERLAY/buildroot/rockchip_rk3566_rk3568_lws_hmi_defconfig"
  if [[ -f "$def" ]]; then
    install_file "$def" "$BR_DEFCONFIGS/rockchip_rk3566_rk3568_lws_hmi_defconfig"
  fi
}

sync_boot_logo() {
  bash "$ROOT/scripts/build-boot-logo.sh"
  local kernel_dir="$SDK/kernel"
  if [[ ! -d "$kernel_dir" ]]; then
    echo "WARNING: $kernel_dir missing; skip boot logo install" >&2
    return 0
  fi
  install_file "$BOARD_DIR/logo/logo.bmp" "$kernel_dir/logo.bmp"
  install_file "$BOARD_DIR/logo/logo_kernel.bmp" "$kernel_dir/logo_kernel.bmp"
}

sync_hmi_app_overlay() {
  local src="$OVERLAY_FS/opt/hmi"
  if [[ ! -d "$src" ]]; then
    return 0
  fi
  mkdir -p "$BR_OVERLAY_ROOT/opt/hmi"
  cp -a "$src/." "$BR_OVERLAY_ROOT/opt/hmi/"
  echo "overlay: synced $BR_OVERLAY_ROOT/opt/hmi"
}

sync_display_params() {
  mkdir -p "$BR_OVERLAY"
  install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" \
    "$BR_OVERLAY/960_lcd_param_rk356x.txt"
  install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" \
    "$BR_OVERLAY/LCD_PARAM_RK356X_V11_0.txt"
  if [[ -f "$BOARD_DIR/lcd_mipi_param.txt" ]]; then
    install_file "$BOARD_DIR/lcd_mipi_param.txt" \
      "$BR_OVERLAY/lcd_mipi_param.txt"
  fi
}

patch_mk_rootfs() {
  local target="$SCRIPTS_DIR/mk-rootfs.sh"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip mk-rootfs patch" >&2
    return 0
  fi
  if [[ ! -f "$target.orig" ]]; then
    cp -a "$target" "$target.orig"
  fi
  cp -a "$target.orig" "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-mk-rootfs.sh" \
    "$target"
  echo "overlay: patched $target (CROOT / defconfig cat fix)"
}

patch_buildroot_config() {
  if grep -q 'lws-hmi-fs-overlay' "$BR_CONFIG" 2>/dev/null; then
    return 0
  fi
  if [[ ! -f "$BR_CONFIG.orig" ]]; then
    cp -a "$BR_CONFIG" "$BR_CONFIG.orig"
  fi
  echo 'BR2_ROOTFS_OVERLAY+="board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/"' \
    >> "$BR_CONFIG"
  echo "overlay: appended lws-hmi BR2_ROOTFS_OVERLAY to $BR_CONFIG"
}

restore_check_sdk=0
restore_all=0
if [[ "${1:-}" == "--restore-check-sdk" ]]; then
  restore_check_sdk=1
elif [[ "${1:-}" == "--restore" ]]; then
  restore_all=1
fi

if [[ "$restore_all" == "1" || "$restore_check_sdk" == "1" ]]; then
  if [[ -f "$SCRIPTS_DIR/check-sdk.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-sdk.sh.orig" "$SCRIPTS_DIR/check-sdk.sh"
    echo "restored upstream check-sdk.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/check-buildroot.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-buildroot.sh.orig" "$SCRIPTS_DIR/check-buildroot.sh"
    echo "restored upstream check-buildroot.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/check-network.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-network.sh.orig" "$SCRIPTS_DIR/check-network.sh"
    echo "restored upstream check-network.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/check-network.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-network.sh.orig" "$SCRIPTS_DIR/check-network.sh"
    echo "restored upstream check-network.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/mk-rootfs.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/mk-rootfs.sh.orig" "$SCRIPTS_DIR/mk-rootfs.sh"
    echo "restored upstream mk-rootfs.sh"
  fi
  if [[ "$restore_all" == "1" && -f "$BR_CONFIG.orig" ]]; then
    mv -f "$BR_CONFIG.orig" "$BR_CONFIG"
    echo "restored upstream $BR_CONFIG"
  fi
  if [[ "$restore_all" == "1" ]]; then
    rm -f "$POST_HOOKS_DIR/05-lws-hmi-display.sh"
    rm -f "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"
    rm -rf "$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay"
    for f in lws_hmi_base.config lws_hmi_systemd.config lws_hmi_network.config lws_hmi_npu.config lws_hmi_flutter.config; do
      rm -f "$BR_CHIPS_DIR/$f"
    done
    rm -f "$BR_DEFCONFIGS/rockchip_rk3566_rk3568_lws_hmi_defconfig"
    rm -f "$SDK/kernel/logo.bmp" "$SDK/kernel/logo_kernel.bmp"
    echo "removed lws-hmi buildroot overlay + post-hooks + chip configs"
  fi
  exit 0
fi

install_file "$BOARD_DIR/ynh960_defconfig" "$CHIP_DIR/ynh960_defconfig"
install_file "$BOARD_DIR/ynh960_defconfig" "$CHIPS_DIR/ynh960_defconfig"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIP_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIPS_DIR/960_lcd_param_rk356x.txt"

if [[ ! -f "$SCRIPTS_DIR/check-sdk.sh.orig" ]]; then
  cp -a "$SCRIPTS_DIR/check-sdk.sh" "$SCRIPTS_DIR/check-sdk.sh.orig"
fi
install_file "$OVERLAY/device/rockchip/common/scripts/check-sdk.sh" "$SCRIPTS_DIR/check-sdk.sh"
chmod +x "$SCRIPTS_DIR/check-sdk.sh"

if [[ ! -f "$SCRIPTS_DIR/check-buildroot.sh.orig" ]]; then
  cp -a "$SCRIPTS_DIR/check-buildroot.sh" "$SCRIPTS_DIR/check-buildroot.sh.orig"
fi
install_file "$OVERLAY/device/rockchip/common/scripts/check-buildroot.sh" \
  "$SCRIPTS_DIR/check-buildroot.sh"
chmod +x "$SCRIPTS_DIR/check-buildroot.sh"

if [[ ! -f "$SCRIPTS_DIR/check-network.sh.orig" ]]; then
  cp -a "$SCRIPTS_DIR/check-network.sh" "$SCRIPTS_DIR/check-network.sh.orig"
fi
install_file "$OVERLAY/device/rockchip/common/scripts/check-network.sh" \
  "$SCRIPTS_DIR/check-network.sh"
chmod +x "$SCRIPTS_DIR/check-network.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/05-lws-hmi-display.sh" \
  "$POST_HOOKS_DIR/05-lws-hmi-display.sh"
chmod +x "$POST_HOOKS_DIR/05-lws-hmi-display.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/06-lws-hmi-systemd.sh" \
  "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"
chmod +x "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"

sync_fs_overlay
sync_display_params
sync_boot_logo
sync_hmi_app_overlay
sync_buildroot_chip_configs
patch_buildroot_config
patch_mk_rootfs

echo "ynh960 board + display + Plan A systemd overlay applied to SDK"
