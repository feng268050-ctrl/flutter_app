#!/usr/bin/env bash
# Prepare SDK for Innohi-native Linux build (ynh960, prebuilt loader/uboot, standard Buildroot).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
BOARD_DIR="$ROOT/board"
OVERLAY="$ROOT/overlay"

CHIP_DIR="$SDK/device/rockchip/rk3566_rk3568"
CHIPS_DIR="$SDK/device/rockchip/.chips/rk3566_rk3568"
SCRIPTS_DIR="$SDK/device/rockchip/common/scripts"

install_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  echo "sdk-native: $dst"
}

restore_upstream_dtsi() {
  local kernel_dts
  for kernel_dts in "$SDK/kernel/arch/arm64/boot/dts/rockchip" \
    "$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip"; do
    [[ -d "$kernel_dts" ]] || continue
    if [[ -f "$kernel_dts/customer_board_ynh960.dtsi.orig" ]]; then
      cp -a "$kernel_dts/customer_board_ynh960.dtsi.orig" \
        "$kernel_dts/customer_board_ynh960.dtsi"
      echo "sdk-native: restored $kernel_dts/customer_board_ynh960.dtsi (PARTUUID root)"
    fi
    # Keep linux-root DTSI out (sdk-native uses vendor chosen/bootargs); display DTSI is applied below.
    rm -f "$kernel_dts/lws-hmi-ynh960-linux-root.dtsi"
  done
}

apply_display_dts() {
  local kernel_dts customer_dtsi patch_script lws_dtsi panel_init_dtsi evb_trim_dtsi touch_dtsi own_gpio_dtsi gen_script
  gen_script="$ROOT/scripts/gen-ynh960-panel-init-dtsi.sh"
  lws_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-display.dtsi"
  panel_init_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-panel-init.dtsi"
  evb_trim_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-evb-trim.dtsi"
  touch_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-touch.dtsi"
  own_gpio_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-own-gpio.dtsi"
  patch_script="$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-ynh960-dts.sh"
  [[ -x "$gen_script" ]] || chmod +x "$gen_script"
  bash "$gen_script"
  for kernel_dts in "$SDK/kernel/arch/arm64/boot/dts/rockchip" \
    "$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip"; do
    [[ -d "$kernel_dts" ]] || continue
    customer_dtsi="$kernel_dts/customer_board_ynh960.dtsi"
    [[ -f "$customer_dtsi" && -f "$patch_script" && -f "$lws_dtsi" && -f "$panel_init_dtsi" && -f "$evb_trim_dtsi" && -f "$touch_dtsi" && -f "$own_gpio_dtsi" ]] || continue
    bash "$patch_script" "$customer_dtsi" \
      "$lws_dtsi" "lws-hmi-ynh960-display.dtsi" \
      "$panel_init_dtsi" "lws-hmi-ynh960-panel-init.dtsi" \
      "$evb_trim_dtsi" "lws-hmi-ynh960-evb-trim.dtsi" \
      "$touch_dtsi" "lws-hmi-ynh960-touch.dtsi" \
      "$own_gpio_dtsi" "lws-hmi-ynh960-own-gpio.dtsi"
    echo "sdk-native: ynh960 MIPI dsi0 + panel-init-sequence in $customer_dtsi"
  done
}

apply_display_kernel_config() {
  local cfg configs_dir
  for cfg in \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-display.config" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-touch.config"; do
    for configs_dir in "$SDK/kernel/arch/arm64/configs" \
      "$SDK/kernel-6.1/arch/arm64/configs"; do
      [[ -f "$cfg" && -d "$configs_dir" ]] || continue
      install_file "$cfg" "$configs_dir/$(basename "$cfg")"
    done
  done
}

sync_boot_logo() {
  local kernel_dir logo logo_kernel
  bash "$ROOT/scripts/build-boot-logo.sh"
  logo="$BOARD_DIR/logo/logo.bmp"
  logo_kernel="$BOARD_DIR/logo/logo_kernel.bmp"
  [[ -f "$logo" && -f "$logo_kernel" ]] || return 0
  for kernel_dir in "$SDK/kernel" "$SDK/kernel-6.1"; do
    [[ -d "$kernel_dir" ]] || continue
    install_file "$logo" "$kernel_dir/logo.bmp"
    install_file "$logo_kernel" "$kernel_dir/logo_kernel.bmp"
  done
}

restore_prebuilt_loader() {
  local mk_loader="$SCRIPTS_DIR/mk-loader.sh"
  local orig="$SCRIPTS_DIR/mk-loader.sh.orig"
  if [[ ! -f "$orig" ]]; then
    echo "WARNING: $orig missing — Innohi prebuilt loader path may not match" >&2
    return 0
  fi
  cp -a "$orig" "$mk_loader"
  echo "sdk-native: mk-loader.sh → prebuilt-only (Innohi original)"
}

apply_innohi_script_fixes() {
  local patch_rootfs="$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-mk-rootfs.sh"
  local patch_wifibt="$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-post-wifibt.sh"
  [[ -x "$patch_rootfs" ]] || chmod +x "$patch_rootfs"
  [[ -x "$patch_wifibt" ]] || chmod +x "$patch_wifibt"
  bash "$patch_rootfs" "$SCRIPTS_DIR/mk-rootfs.sh"
  bash "$patch_wifibt" "$SCRIPTS_DIR/post-wifibt.sh"
  echo "sdk-native: mk-rootfs CROOT + Innohi mk-rootfs path; post-wifibt firmware fix"
}

apply_network_check_patches() {
  local check_br="$OVERLAY/device/rockchip/common/scripts/check-buildroot.sh"
  local check_net="$OVERLAY/device/rockchip/common/scripts/check-network.sh"
  [[ -f "$check_br" && -f "$check_net" ]] || return 0
  if [[ ! -f "$SCRIPTS_DIR/check-buildroot.sh.orig" ]]; then
    cp -a "$SCRIPTS_DIR/check-buildroot.sh" "$SCRIPTS_DIR/check-buildroot.sh.orig"
  fi
  if [[ ! -f "$SCRIPTS_DIR/check-network.sh.orig" ]]; then
    cp -a "$SCRIPTS_DIR/check-network.sh" "$SCRIPTS_DIR/check-network.sh.orig"
  fi
  install_file "$check_br" "$SCRIPTS_DIR/check-buildroot.sh"
  install_file "$check_net" "$SCRIPTS_DIR/check-network.sh"
  chmod +x "$SCRIPTS_DIR/check-buildroot.sh" "$SCRIPTS_DIR/check-network.sh"
  echo "sdk-native: patched check-buildroot.sh + check-network.sh (buildroot.net probe)"
}

install_innohi_native_buildroot_defconfig() {
  local br_cfg="$SDK/buildroot/configs"
  local tools_cfg="$OVERLAY/buildroot/tools/innohi-native-tools.config"
  local def="$BOARD_DIR/buildroot/rockchip_rk3566_rk3568_innohi_native_defconfig"
  [[ -d "$br_cfg" && -f "$def" && -f "$tools_cfg" ]] || return 0
  install_file "$tools_cfg" "$br_cfg/rockchip/tools/innohi-native-tools.config"
  install_file "$def" "$br_cfg/rockchip_rk3566_rk3568_innohi_native_defconfig"
  echo "sdk-native: Buildroot defconfig rockchip_rk3566_rk3568_innohi_native (no camera/rkaiq)"
}

fix_innohi_scripts_buildroot_output_dir() {
  local f
  for f in "$SCRIPTS_DIR/mk-rootfs.sh" "$SCRIPTS_DIR/post-wifibt.sh"; do
    [[ -f "$f" ]] || continue
    if grep -q 'buildroot/output/rockchip_rk3566_rk3568/target' "$f"; then
      sed -i.bak 's|buildroot/output/rockchip_rk3566_rk3568/target|buildroot/output/${RK_BUILDROOT_CFG}/target|g' "$f"
      rm -f "$f.bak"
      echo "sdk-native: fixed Buildroot output path in $(basename "$f")"
    fi
  done
}

[[ -d "$SDK" ]] || { echo "ERROR: SDK missing at $SDK" >&2; exit 1; }

echo "=== SDK native prepare (Innohi ynh960) ==="

bash "$ROOT/scripts/sync-innohi-board.sh"

install_file "$BOARD_DIR/ynh960_innohi_defconfig" "$CHIPS_DIR/ynh960_innohi_defconfig"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIPS_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/parameter-buildroot-fit.txt" "$CHIPS_DIR/parameter-buildroot-fit.txt"

restore_prebuilt_loader
apply_innohi_script_fixes
fix_innohi_scripts_buildroot_output_dir
apply_network_check_patches
install_innohi_native_buildroot_defconfig
restore_upstream_dtsi
apply_display_dts
apply_display_kernel_config
sync_boot_logo

echo "sdk-native: ready — lunch rk3566_rk3568:ynh960_innohi_defconfig then ./build.sh"
