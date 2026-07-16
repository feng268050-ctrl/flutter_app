#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
BOARD_DIR="$ROOT/board"
OVERLAY="$ROOT/overlay"

if [[ ! -d "$SDK" ]]; then
  echo "ERROR: Linux SDK missing at $SDK" >&2
  exit 1
fi

CHIP_DIR="$SDK/device/rockchip/rk3566_rk3568"
CHIPS_DIR="$SDK/device/rockchip/.chips/rk3566_rk3568"
SCRIPTS_DIR="$SDK/device/rockchip/common/scripts"
POST_HOOKS_DIR="$SDK/device/rockchip/common/post-hooks"
HOOKS_DIR="$SDK/device/rockchip/common/build-hooks"
BR_CONFIG="$SDK/buildroot/configs/rockchip/chips/rk3566_rk3568.config"
BR_CHIPS_DIR="$SDK/buildroot/configs/rockchip/chips"
BR_DEFCONFIGS="$SDK/buildroot/configs"
BR_PKG_FLUTTER_ENGINE="$SDK/buildroot/package/flutter-engine"
BR_PKG_FLUTTER_SDK="$SDK/buildroot/package/flutter-sdk-bin"
BR_PKG_FLUTTER_PI="$SDK/buildroot/package/flutter-pi"
BR_PKG_LIBSERIALPORT="$SDK/buildroot/package/libserialport"
BR_PKG_SOURCE_HAN_SANS_CN="$SDK/buildroot/package/source-han-sans/source-han-sans-cn"
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

LWS_PREBUILT_PATCHES_DIR=".lws-prebuilt-patches-disabled"

# Prebuilt-only .mk extracts an empty dir; SDK *.patch must not run (no engine sources).
disable_br_package_patches() {
  local pkg_dir="$1"
  local label="$2"
  local stash="$pkg_dir/$LWS_PREBUILT_PATCHES_DIR"
  [[ -d "$pkg_dir" ]] || return 0
  mkdir -p "$stash"
  shopt -s nullglob
  local moved=0
  for p in "$pkg_dir"/*.patch; do
    mv "$p" "$stash/"
    moved=1
  done
  shopt -u nullglob
  if [[ "$moved" == 1 ]]; then
    echo "overlay: disabled upstream patches for ${label} (prebuilt install .mk)"
  fi
}

restore_br_package_patches() {
  local pkg_dir="$1"
  local label="$2"
  local stash="$pkg_dir/$LWS_PREBUILT_PATCHES_DIR"
  [[ -d "$stash" ]] || return 0
  shopt -s nullglob
  local restored=0
  for p in "$stash"/*.patch; do
    mv "$p" "$pkg_dir/"
    restored=1
  done
  shopt -u nullglob
  rmdir "$stash" 2>/dev/null || true
  if [[ "$restored" == 1 ]]; then
    echo "overlay: restored upstream patches for ${label}"
  fi
}

sync_fs_overlay() {
  if [[ ! -d "$OVERLAY_FS" ]]; then
    echo "WARNING: $OVERLAY_FS missing; skip fs-overlay sync" >&2
    return 0
  fi
  mkdir -p "$BR_OVERLAY_ROOT"
  # Plan A: etc/ (systemd) + usr/ (scripts) + var/ (persistent prefs, e.g. wpa/http-proxy).
  # system/etc from sync_display_params; opt/hmi from sync_hmi_app_overlay.
  # Use rsync --delete so removed overlay files (e.g. lws-hmi-debug-boot.service) do not linger in the SDK tree.
  for sub in etc usr var; do
    if [[ -d "$OVERLAY_FS/$sub" ]]; then
      mkdir -p "$BR_OVERLAY_ROOT/$sub"
      if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete "$OVERLAY_FS/$sub/" "$BR_OVERLAY_ROOT/$sub/"
      else
        rm -rf "$BR_OVERLAY_ROOT/$sub"
        mkdir -p "$BR_OVERLAY_ROOT/$sub"
        cp -a "$OVERLAY_FS/$sub/." "$BR_OVERLAY_ROOT/$sub/"
      fi
      echo "overlay: synced $BR_OVERLAY_ROOT/$sub"
    fi
  done
  # Single-image policy: ensure retired artifacts are gone even before next full rootfs rebuild.
  rm -f \
    "$BR_OVERLAY_ROOT/etc/systemd/system/lws-hmi-debug-boot.service" \
    "$BR_OVERLAY_ROOT/etc/systemd/system/lws-hmi-boot-kpi.service" \
    "$BR_OVERLAY_ROOT/usr/lib/lws-hmi/debug-boot.sh" \
    "$BR_OVERLAY_ROOT/usr/lib/lws-hmi/boot-kpi-watch.sh" \
    "$BR_OVERLAY_ROOT/usr/lib/lws-hmi/configure-camera-eth0.sh"
}

sync_post_build_script() {
  local src="$OVERLAY/board/rockchip/rk3566_rk3568/lws-hmi-post-build.sh"
  local dest="$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-post-build.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip post-build script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_post_fakeroot_script() {
  local src="$OVERLAY/board/rockchip/rk3566_rk3568/lws-hmi-post-fakeroot.sh"
  local dest="$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-post-fakeroot.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip post-fakeroot script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_strip_fstab_script() {
  local src="$OVERLAY/board/rockchip/rk3566_rk3568/lws-hmi-strip-fstab.sh"
  local dest="$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-strip-fstab.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip strip-fstab script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_flutter_engine_script() {
  local src="$OVERLAY/board/rockchip/rk3566_rk3568/lws-hmi-sync-flutter-engine.sh"
  local dest="$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-sync-flutter-engine.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip flutter engine sync script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_kernel_display_dts() {
  local kernel_dts="$SDK/kernel/arch/arm64/boot/dts/rockchip"
  local customer_dtsi="$kernel_dts/customer_board_ynh960.dtsi"
  local lws_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-display.dtsi"
  local panel_init_dtsi="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-panel-init.dtsi"
  local gen_script="$ROOT/scripts/gen-ynh960-panel-init-dtsi.sh"
  local lws_root="$OVERLAY/kernel/rockchip/lws-hmi-ynh960-linux-root.dtsi"
  local patch_script="$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-ynh960-dts.sh"

  if [[ ! -d "$kernel_dts" ]]; then
    kernel_dts="$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip"
    customer_dtsi="$kernel_dts/customer_board_ynh960.dtsi"
  fi
  if [[ ! -f "$customer_dtsi" ]]; then
    echo "WARNING: $customer_dtsi missing; skip ynh960 display DTS patch" >&2
    return 0
  fi
  if [[ ! -f "$lws_dtsi" || ! -f "$lws_root" || ! -f "$patch_script" ]]; then
    echo "WARNING: lws-hmi ynh960 DTS overlay missing; skip" >&2
    return 0
  fi
  [[ -x "$gen_script" ]] || chmod +x "$gen_script"
  bash "$gen_script"
  if [[ ! -f "$customer_dtsi.orig" ]]; then
    cp -a "$customer_dtsi" "$customer_dtsi.orig"
  fi
  cp -a "$customer_dtsi.orig" "$customer_dtsi"
  bash "$patch_script" "$customer_dtsi" \
    "$lws_dtsi" "lws-hmi-ynh960-display.dtsi" \
    "$panel_init_dtsi" "lws-hmi-ynh960-panel-init.dtsi" \
    "$lws_root" "lws-hmi-ynh960-linux-root.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-usb-gadget.dtsi" "lws-hmi-ynh960-usb-gadget.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-usb-host.dtsi" "lws-hmi-ynh960-usb-host.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-evb-trim.dtsi" "lws-hmi-ynh960-evb-trim.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-touch.dtsi" "lws-hmi-ynh960-touch.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-own-gpio.dtsi" "lws-hmi-ynh960-own-gpio.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-uart5-gmac.dtsi" "lws-hmi-ynh960-uart5-gmac.dtsi" \
    "$OVERLAY/kernel/rockchip/lws-hmi-ynh960-uart7-pwm.dtsi" "lws-hmi-ynh960-uart7-pwm.dtsi"
}

sync_kernel_config_fragments() {
  local configs_dir="$SDK/kernel/arch/arm64/configs"
  if [[ ! -d "$configs_dir" ]]; then
    configs_dir="$SDK/kernel-6.1/arch/arm64/configs"
  fi
  if [[ ! -d "$configs_dir" ]]; then
    echo "WARNING: skip kernel config fragments" >&2
    return 0
  fi
  for cfg in "$OVERLAY/kernel/rockchip"/lws-hmi-*.config; do
    [[ -f "$cfg" ]] || continue
    install_file "$cfg" "$configs_dir/$(basename "$cfg")"
  done
}

kernel_source_dir() {
  if [[ -d "$SDK/kernel/drivers/gpu/drm" ]]; then
    echo "$SDK/kernel"
  else
    echo "$SDK/kernel-6.1"
  fi
}

apply_kernel_patches() {
  local kernel patch_dir relative target backup patch_file
  local -a patched_files=(
    "include/drm/drm_drv.h"
    "drivers/gpu/drm/drm_gem.c"
    "drivers/gpu/drm/rockchip/rockchip_drm_drv.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.h"
  )
  kernel="$(kernel_source_dir)"
  patch_dir="$OVERLAY/kernel/patches"

  [[ -d "$patch_dir" ]] || return 0
  for relative in "${patched_files[@]}"; do
    target="$kernel/$relative"
    backup="$target.lws-hmi.orig"
    if [[ ! -f "$target" ]]; then
      echo "ERROR: missing kernel source: $target" >&2
      return 1
    fi
    if [[ ! -f "$backup" ]]; then
      cp -a "$target" "$backup"
    fi
    cp -a "$backup" "$target"
  done

  for patch_file in "$patch_dir"/*.patch; do
    [[ -f "$patch_file" ]] || continue
    patch --batch --forward -d "$kernel" -p1 < "$patch_file"
    echo "overlay: applied kernel patch $(basename "$patch_file")"
  done
}

restore_kernel_patches() {
  local kernel relative target backup
  local -a patched_files=(
    "include/drm/drm_drv.h"
    "drivers/gpu/drm/drm_gem.c"
    "drivers/gpu/drm/rockchip/rockchip_drm_drv.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.h"
  )
  kernel="$(kernel_source_dir)"
  for relative in "${patched_files[@]}"; do
    target="$kernel/$relative"
    backup="$target.lws-hmi.orig"
    if [[ -f "$backup" ]]; then
      mv -f "$backup" "$target"
      echo "restored upstream kernel source: $relative"
    fi
  done
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
  bash "$ROOT/scripts/generate-lws-hmi-defconfig.sh"
  local gen="$OVERLAY/buildroot/.generated/rockchip_rk3566_rk3568_lws_hmi_defconfig"
  if [[ -f "$gen" ]]; then
    install_file "$gen" "$BR_DEFCONFIGS/rockchip_rk3566_rk3568_lws_hmi_defconfig"
  fi
}

sync_flutter_engine_package() {
  local src="$OVERLAY/buildroot/package/flutter-engine/flutter-engine.mk"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk" \
      "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig"
  fi
  install_file "$src" "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk"
  disable_br_package_patches "$BR_PKG_FLUTTER_ENGINE" "flutter-engine"
}

sync_flutter_sdk_package() {
  local src="$OVERLAY/buildroot/package/flutter-sdk-bin/flutter-sdk-bin.mk"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk" \
      "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk.orig"
  fi
  install_file "$src" "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk"
}

sync_flutter_pi_package() {
  local src="$OVERLAY/buildroot/package/flutter-pi/flutter-pi.mk"
  local patch_src patch_name
  local mark="$BR_PKG_FLUTTER_PI/.lws-overlay-patches"
  local stash="$BR_PKG_FLUTTER_PI/$LWS_PREBUILT_PATCHES_DIR"
  local prev
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$BR_PKG_FLUTTER_PI/flutter-pi.mk.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_PI/flutter-pi.mk" \
      "$BR_PKG_FLUTTER_PI/flutter-pi.mk.orig"
  fi
  install_file "$src" "$BR_PKG_FLUTTER_PI/flutter-pi.mk"

  # Drop retired LWS overlay patches (install is additive; stash otherwise keeps
  # obsolete 0009-*.patch and breaks compile when two 0009s both apply).
  if [[ -f "$mark" ]]; then
    while IFS= read -r prev || [[ -n "${prev:-}" ]]; do
      [[ -z "$prev" ]] && continue
      rm -f "$BR_PKG_FLUTTER_PI/$prev" "$stash/$prev"
    done <"$mark"
  fi
  # Known retired names (mark may be missing on older trees).
  rm -f \
    "$BR_PKG_FLUTTER_PI/0009-pointer-relative-display-axes.patch" \
    "$stash/0009-pointer-relative-display-axes.patch" \
    "$BR_PKG_FLUTTER_PI/0009-qm002-pointer-axis-swap.patch" \
    "$stash/0009-qm002-pointer-axis-swap.patch"

  : >"$mark"
  shopt -s nullglob
  for patch_src in "$OVERLAY/buildroot/package/flutter-pi"/*.patch; do
    patch_name="$(basename "$patch_src")"
    install_file "$patch_src" "$BR_PKG_FLUTTER_PI/$patch_name"
    printf '%s\n' "$patch_name" >>"$mark"
  done
  shopt -u nullglob
  # Install overlay patches before stashing (prebuilt .mk); br-compile-flutter
  # restores them when swapping to flutter-pi.compile.mk.
  disable_br_package_patches "$BR_PKG_FLUTTER_PI" "flutter-pi"
  patch_flutter_pi_config_prebuilt
}

# libserialport 0.1.1 probes removed Linux termiox → sp_open ENOTTY on kernel 6.1+.
sync_libserialport_package() {
  local src="$OVERLAY/buildroot/package/libserialport/0002-dont-check-termiox.patch"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -d "$BR_PKG_LIBSERIALPORT" ]]; then
    echo "overlay: skip libserialport patch (package dir missing)" >&2
    return 0
  fi
  install_file "$src" "$BR_PKG_LIBSERIALPORT/0002-dont-check-termiox.patch"
}

# bluez-alsa --enable-debug AC_CHECK_LIB(SegFault) → -lSegFault, but target lacks the .so.
# Also install A2DP-Sink softvol patch (skip broken AVRCP Absolute Volume write).
sync_bluez_alsa_package() {
  local pkg="$SDK/buildroot/package/bluez-alsa"
  local mk="$pkg/bluez-alsa.mk"
  local vol_patch_src="$OVERLAY/buildroot/package/bluez-alsa/0002-lws-a2dp-sink-softvol-skip-avrcp.patch"
  if [[ ! -f "$mk" ]]; then
    echo "overlay: skip bluez-alsa.mk (package missing)" >&2
    return 0
  fi
  if [[ ! -f "${mk}.lws-orig" ]]; then
    cp -a "$mk" "${mk}.lws-orig"
  fi
  cp -a "${mk}.lws-orig" "$mk"
  if grep -q -- '--enable-debug' "$mk"; then
    sed -i.bak 's/--enable-debug/--disable-debug/' "$mk"
    rm -f "$mk.bak"
  fi
  if ! grep -q 'ac_cv_lib_SegFault_backtrace=no' "$mk"; then
    awk '
      BEGIN { done = 0 }
      /^BLUEZ_ALSA_CONF_OPTS/ && !done {
        print "BLUEZ_ALSA_CONF_ENV = ac_cv_lib_SegFault_backtrace=no"
        done = 1
      }
      { print }
    ' "$mk" >"${mk}.tmp" && mv "${mk}.tmp" "$mk"
  fi
  echo "overlay: bluez-alsa.mk — disable-debug + no -lSegFault"
  if [[ -f "$vol_patch_src" ]]; then
    install_file "$vol_patch_src" "$pkg/0002-lws-a2dp-sink-softvol-skip-avrcp.patch"
  fi
}

patch_flutter_pi_config_prebuilt() {
  local cfg="$BR_PKG_FLUTTER_PI/Config.in"
  [[ -f "$cfg" ]] || return 0
  if [[ ! -f "$cfg.lws-prebuilt.orig" ]]; then
    cp -a "$cfg" "$cfg.lws-prebuilt.orig"
  fi
  if grep -q 'select BR2_PACKAGE_HOST_FLUTTER_SDK_BIN' "$cfg"; then
    sed -i.bak '/select BR2_PACKAGE_HOST_FLUTTER_SDK_BIN/d' "$cfg"
    rm -f "$cfg.bak"
    echo "overlay: flutter-pi Config.in — drop select HOST_FLUTTER_SDK_BIN (prebuilt rootfs)"
  fi
}

restore_flutter_pi_config() {
  local cfg="$BR_PKG_FLUTTER_PI/Config.in"
  if [[ -f "$cfg.lws-prebuilt.orig" ]]; then
    mv -f "$cfg.lws-prebuilt.orig" "$cfg"
    echo "overlay: restored upstream flutter-pi Config.in"
  fi
}

sdk_realpath() {
  python3 - "$1" <<'PY'
import os, sys
print(os.path.realpath(sys.argv[1]))
PY
}

restore_sdk_script() {
  local target="$1"
  local real orig
  real="$(sdk_realpath "$target")"
  orig="${real}.orig"
  if [[ -f "$orig" ]]; then
    cp -a "$orig" "$real"
    echo "restored upstream $(basename "$real")"
  fi
}

backup_sdk_script() {
  local target="$1"
  local real orig
  real="$(sdk_realpath "$target")"
  orig="${real}.orig"
  if [[ ! -f "$orig" ]]; then
    cp -a "$real" "$orig"
  fi
  cp -a "$orig" "$real"
}

sync_source_han_sans_cn_package() {
  local src="$OVERLAY/buildroot/package/source-han-sans-cn/source-han-sans-cn.mk"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" ]]; then
    cp -a "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk" \
      "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig"
  fi
  install_file "$src" "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk"
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
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$BR_OVERLAY_ROOT/opt/hmi/"
  else
    rm -rf "$BR_OVERLAY_ROOT/opt/hmi"
    mkdir -p "$BR_OVERLAY_ROOT/opt/hmi"
    cp -a "$src/." "$BR_OVERLAY_ROOT/opt/hmi/"
  fi
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

patch_mk_loader() {
  local target="$SCRIPTS_DIR/mk-loader.sh"
  local orig="$SCRIPTS_DIR/mk-loader.sh.orig"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip mk-loader restore" >&2
    return 0
  fi
  if [[ ! -f "$orig" ]]; then
    cp -a "$target" "$orig"
  fi
  cp -a "$orig" "$target"
  echo "overlay: mk-loader.sh → Innohi prebuilt loader (sdk-native verified path)"
}

fix_innohi_scripts_buildroot_output_dir() {
  local f
  for f in "$SCRIPTS_DIR/mk-rootfs.sh" "$SCRIPTS_DIR/post-wifibt.sh"; do
    [[ -f "$f" ]] || continue
    if grep -q 'buildroot/output/rockchip_rk3566_rk3568/target' "$f"; then
      sed -i.bak 's|buildroot/output/rockchip_rk3566_rk3568/target|buildroot/output/${RK_BUILDROOT_CFG}/target|g' "$f"
      rm -f "$f.bak"
      echo "overlay: fixed Buildroot output path in $(basename "$f")"
    fi
  done
}

patch_mk_rootfs() {
  local target="$SCRIPTS_DIR/mk-rootfs.sh"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip mk-rootfs patch" >&2
    return 0
  fi
  backup_sdk_script "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-mk-rootfs.sh" \
    "$(sdk_realpath "$target")"
  echo "overlay: patched $(basename "$(sdk_realpath "$target")") (CROOT / defconfig / lws_hmi Innohi skip)"
}

patch_30_rootfs() {
  local target="$HOOKS_DIR/30-rootfs.sh"
  local mk_real hook_real
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip 30-rootfs patch" >&2
    return 0
  fi
  mk_real="$(sdk_realpath "$SCRIPTS_DIR/mk-rootfs.sh")"
  hook_real="$(sdk_realpath "$target")"
  if [[ "$mk_real" == "$hook_real" ]]; then
    echo "overlay: 30-rootfs.sh → mk-rootfs.sh (same file; Innohi skip via patch_mk_rootfs)"
    return 0
  fi
  backup_sdk_script "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-30-rootfs.sh" \
    "$hook_real"
  echo "overlay: patched 30-rootfs.sh (lws_hmi Innohi MainServer skip)"
}

patch_post_wifibt() {
  local target="$SCRIPTS_DIR/post-wifibt.sh"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip post-wifibt patch" >&2
    return 0
  fi
  if [[ ! -f "$target.orig" ]]; then
    cp -a "$target" "$target.orig"
  fi
  cp -a "$target.orig" "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/lws-hmi-patch-post-wifibt.sh" \
    "$target"
  echo "overlay: patched $target (CROOT + innohi firmware fallback)"
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
  if [[ -f "$SCRIPTS_DIR/check-loader.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-loader.sh.orig" "$SCRIPTS_DIR/check-loader.sh"
    echo "restored upstream check-loader.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/check-network.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/check-network.sh.orig" "$SCRIPTS_DIR/check-network.sh"
    echo "restored upstream check-network.sh"
  fi
  restore_sdk_script "$SCRIPTS_DIR/mk-rootfs.sh"
  if [[ -f "$(sdk_realpath "$HOOKS_DIR/30-rootfs.sh")" ]]; then
    hook_real="$(sdk_realpath "$HOOKS_DIR/30-rootfs.sh")"
    mk_real="$(sdk_realpath "$SCRIPTS_DIR/mk-rootfs.sh")"
    if [[ "$hook_real" != "$mk_real" ]]; then
      restore_sdk_script "$HOOKS_DIR/30-rootfs.sh"
    fi
  fi
  if [[ -f "$SCRIPTS_DIR/mk-loader.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/mk-loader.sh.orig" "$SCRIPTS_DIR/mk-loader.sh"
    echo "restored upstream mk-loader.sh"
  fi
  if [[ -f "$SCRIPTS_DIR/post-wifibt.sh.orig" ]]; then
    mv -f "$SCRIPTS_DIR/post-wifibt.sh.orig" "$SCRIPTS_DIR/post-wifibt.sh"
    echo "restored upstream post-wifibt.sh"
  fi
  if [[ "$restore_all" == "1" && -f "$BR_CONFIG.orig" ]]; then
    mv -f "$BR_CONFIG.orig" "$BR_CONFIG"
    echo "restored upstream $BR_CONFIG"
  fi
  if [[ "$restore_all" == "1" ]]; then
    rm -f "$POST_HOOKS_DIR/05-lws-hmi-display.sh"
    rm -f "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"
    rm -f "$POST_HOOKS_DIR/07-lws-hmi-innohi-display-bin.sh"
    rm -f "$POST_HOOKS_DIR/08-lws-hmi-systemd-finalize.sh"
    rm -f "$POST_HOOKS_DIR/09-lws-hmi-wifibt-innohi.sh"
    rm -rf "$SDK/buildroot/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay"
    for f in lws_hmi_base.config lws_hmi_systemd.config lws_hmi_network.config lws_hmi_npu.config lws_hmi_flutter.config lws_hmi_font.config lws_hmi_bt.config lws_hmi_gst_rtsp.config lws_hmi_build.config lws_hmi_toolchain_external.config lws_hmi_gst_prebuilt.config lws_hmi_platform_prebuilt.config; do
      rm -f "$BR_CHIPS_DIR/$f"
    done
    for f in rockchip_rk3566_rk3568_lws_hmi_defconfig; do
      rm -f "$BR_DEFCONFIGS/$f"
    done
    if [[ -f "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig" ]]; then
      mv -f "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig" \
        "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk"
      echo "restored upstream flutter-engine.mk"
    fi
    restore_br_package_patches "$BR_PKG_FLUTTER_ENGINE" "flutter-engine"
    if [[ -f "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk.orig" ]]; then
      mv -f "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk.orig" \
        "$BR_PKG_FLUTTER_SDK/flutter-sdk-bin.mk"
      echo "restored upstream flutter-sdk-bin.mk"
    fi
    if [[ -f "$BR_PKG_FLUTTER_PI/flutter-pi.mk.orig" ]]; then
      mv -f "$BR_PKG_FLUTTER_PI/flutter-pi.mk.orig" \
        "$BR_PKG_FLUTTER_PI/flutter-pi.mk"
      echo "restored upstream flutter-pi.mk"
    fi
    restore_br_package_patches "$BR_PKG_FLUTTER_PI" "flutter-pi"
    restore_flutter_pi_config
    if [[ -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" ]]; then
      mv -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" \
        "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk"
      echo "restored upstream source-han-sans-cn.mk"
    fi
    rm -f "$SDK/kernel/logo.bmp" "$SDK/kernel/logo_kernel.bmp"
    for kernel_dts in "$SDK/kernel/arch/arm64/boot/dts/rockchip" \
      "$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip"; do
      if [[ -f "$kernel_dts/customer_board_ynh960.dtsi.orig" ]]; then
        mv -f "$kernel_dts/customer_board_ynh960.dtsi.orig" \
          "$kernel_dts/customer_board_ynh960.dtsi"
        echo "restored upstream customer_board_ynh960.dtsi"
      fi
      rm -f "$kernel_dts/lws-hmi-ynh960-display.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-linux-root.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-usb-gadget.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-usb-host.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-evb-trim.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-touch.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-own-gpio.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-uart5-gmac.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-uart7-pwm.dtsi"
      rm -f "$kernel_dts/lws-hmi-ynh960-panel-init.dtsi"
    done
    restore_kernel_patches
    echo "removed lws-hmi buildroot overlay + post-hooks + chip configs"
  fi
  exit 0
fi

install_file "$BOARD_DIR/ynh960_defconfig" "$CHIP_DIR/ynh960_defconfig"
install_file "$BOARD_DIR/ynh960_defconfig" "$CHIPS_DIR/ynh960_defconfig"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIP_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIPS_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/parameter-buildroot-fit.txt" "$CHIP_DIR/parameter-buildroot-fit.txt"
install_file "$BOARD_DIR/parameter-buildroot-fit.txt" "$CHIPS_DIR/parameter-buildroot-fit.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-gpt.txt" "$CHIP_DIR/parameter-ynh960-android-gpt.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-gpt.txt" "$CHIPS_DIR/parameter-ynh960-android-gpt.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-stock.txt" "$CHIP_DIR/parameter-ynh960-android-stock.txt"
install_file "$BOARD_DIR/boot-slim.its" "$CHIP_DIR/boot-slim.its"
install_file "$BOARD_DIR/boot-slim.its" "$CHIPS_DIR/boot-slim.its"
install_file "$BOARD_DIR/package-file-ynh960-linux-ab" "$CHIP_DIR/package-file-ynh960-linux-ab"
install_file "$BOARD_DIR/package-file-ynh960-linux-ab" "$CHIPS_DIR/package-file-ynh960-linux-ab"

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

if [[ ! -f "$SCRIPTS_DIR/check-loader.sh.orig" ]]; then
  cp -a "$SCRIPTS_DIR/check-loader.sh" "$SCRIPTS_DIR/check-loader.sh.orig"
fi
install_file "$OVERLAY/device/rockchip/common/scripts/check-loader.sh" \
  "$SCRIPTS_DIR/check-loader.sh"
chmod +x "$SCRIPTS_DIR/check-loader.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/05-lws-hmi-display.sh" \
  "$POST_HOOKS_DIR/05-lws-hmi-display.sh"
chmod +x "$POST_HOOKS_DIR/05-lws-hmi-display.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/06-lws-hmi-systemd.sh" \
  "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"
chmod +x "$POST_HOOKS_DIR/06-lws-hmi-systemd.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/07-lws-hmi-innohi-display-bin.sh" \
  "$POST_HOOKS_DIR/07-lws-hmi-innohi-display-bin.sh"
chmod +x "$POST_HOOKS_DIR/07-lws-hmi-innohi-display-bin.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/08-lws-hmi-systemd-finalize.sh" \
  "$POST_HOOKS_DIR/08-lws-hmi-systemd-finalize.sh"
chmod +x "$POST_HOOKS_DIR/08-lws-hmi-systemd-finalize.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/09-lws-hmi-wifibt-innohi.sh" \
  "$POST_HOOKS_DIR/09-lws-hmi-wifibt-innohi.sh"
chmod +x "$POST_HOOKS_DIR/09-lws-hmi-wifibt-innohi.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/31-lws-hmi-strip-fstab.sh" \
  "$POST_HOOKS_DIR/31-lws-hmi-strip-fstab.sh"
chmod +x "$POST_HOOKS_DIR/31-lws-hmi-strip-fstab.sh"

sync_fs_overlay
sync_post_build_script
sync_post_fakeroot_script
sync_strip_fstab_script
sync_flutter_engine_script
sync_kernel_display_dts
sync_kernel_config_fragments
apply_kernel_patches
sync_display_params
sync_boot_logo
sync_hmi_app_overlay
sync_buildroot_chip_configs
sync_flutter_engine_package
sync_flutter_sdk_package
sync_flutter_pi_package
sync_libserialport_package
sync_bluez_alsa_package
sync_source_han_sans_cn_package
patch_buildroot_config
patch_mk_loader
patch_mk_rootfs
patch_30_rootfs
patch_post_wifibt
fix_innohi_scripts_buildroot_output_dir
bash "$ROOT/scripts/sync-innohi-board.sh"
bash "$ROOT/scripts/sync-prebuilt-overlays.sh"

echo "ynh960 board + display + Plan A systemd overlay applied to SDK"
