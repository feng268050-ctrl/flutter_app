#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
BOARD_DIR="$ROOT/board"
OVERLAY="$ROOT/overlay"

if [[ ! -d "$SDK" ]]; then
  echo "ERROR: Linux SDK missing at $SDK" >&2
  exit 1
fi

# shellcheck source=platform-paths.sh
source "$ROOT/scripts/platform-paths.sh"
platform_paths_init "$ROOT" "$SDK"

BR_DEFCONFIGS="$SDK/buildroot/configs"
BR_PKG_FLUTTER_ENGINE="$SDK/buildroot/package/flutter-engine"
BR_PKG_FLUTTER_SDK="$SDK/buildroot/package/flutter-sdk-bin"
BR_PKG_FLUTTER_ELINUX="$SDK/buildroot/package/flutter-embedded-linux"
BR_PKG_LIBSERIALPORT="$SDK/buildroot/package/libserialport"
BR_PKG_BLUEZ5_UTILS="$SDK/buildroot/package/bluez5_utils"
BR_PKG_BLUEZ5_UTILS_HEADERS="$SDK/buildroot/package/bluez5_utils-headers"
BR_PKG_SOURCE_HAN_SANS_CN="$SDK/buildroot/package/source-han-sans/source-han-sans-cn"
BR_PKG_MESON="$SDK/buildroot/package/meson"
BR_PKG_SYSTEMD="$SDK/buildroot/package/systemd"
BR_PKG_GSTREAMER1="$SDK/buildroot/package/gstreamer1"
BR_PKG_LIBOPENSSL="$SDK/buildroot/package/libopenssl"
LWS_ROCKCHIP_BLUEZ_PATCH_STASH=".lws-rockchip-bluez-patch-disabled"
LWS_ROCKCHIP_GST_PATCH_STASH=".lws-rockchip-gst-patches-disabled"
LWS_ROCKCHIP_MESON_PATCH_STASH=".lws-rockchip-meson-patches-disabled"
LWS_ROCKCHIP_OPENSSL_PATCH_STASH=".lws-rockchip-openssl-patches-disabled"

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

purge_legacy_fs_overlay() {
  local legacy="$BR_BOARD/lws-hmi-fs-overlay"
  if [[ -d "$legacy" ]]; then
    rm -rf "$legacy"
    echo "overlay: removed legacy $legacy (superseded by rootfs-overlay/)"
  fi
  local cfg
  for cfg in \
    "$BR_CONFIG" \
    "$BR_CHIPS_DIR/${LWS_CHIP}_lws.config" \
    "$OVERLAY/buildroot/${LWS_CHIP}_lws.config"; do
    [[ -f "$cfg" ]] || continue
    if grep -q 'lws-hmi-fs-overlay' "$cfg" 2>/dev/null; then
      sed -i.bak '/lws-hmi-fs-overlay/d' "$cfg"
      rm -f "$cfg.bak"
      echo "overlay: purged lws-hmi-fs-overlay from ${cfg#$ROOT/}"
    fi
  done
}

purge_stale_fs_overlay_opt() {
  # App bundles belong in app/<APP>/build/bundle/release — never repo fs-overlay.
  # SDK rootfs-overlay/opt/ is staged only by make build-rootfs (sync-opt-app-overlay).
  local removed=0

  if [[ -d "$OVERLAY_FS/opt" ]]; then
    rm -rf "$OVERLAY_FS/opt"
    echo "overlay: purged stale app bundle $OVERLAY_FS/opt"
    removed=1
  fi
  if [[ -d "$BR_OVERLAY_ROOT/opt" ]]; then
    rm -rf "$BR_OVERLAY_ROOT/opt"
    echo "overlay: purged stale app bundle $BR_OVERLAY_ROOT/opt (re-stage: make build-rootfs)"
    removed=1
  fi
  if [[ "$removed" == 0 ]]; then
    echo "overlay: no stale fs-overlay opt/ app bundles"
  fi
}

sync_fs_overlay() {
  purge_stale_fs_overlay_opt
  purge_legacy_fs_overlay
  if [[ ! -d "$OVERLAY_FS" ]]; then
    echo "WARNING: $OVERLAY_FS missing; skip fs-overlay sync" >&2
    return 0
  fi
  mkdir -p "$BR_OVERLAY_ROOT"
  # Generic OS: etc/ + usr/ + var/. Do NOT sync top-level lib/ (merged-/usr).
  # opt/{hmi,os_settings} staged by build-rootfs into this common overlay.
  # --delete so removed overlay files do not linger in the SDK tree.
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
      echo "overlay: synced common $BR_OVERLAY_ROOT/$sub"
    fi
  done
  if [[ -d "$BR_OVERLAY_ROOT/lib" ]]; then
    rm -rf "$BR_OVERLAY_ROOT/lib"
    echo "overlay: removed non-merged $BR_OVERLAY_ROOT/lib (use usr/lib/)"
  fi
  if [[ -d "$OVERLAY_FS/lib" ]]; then
    echo "WARNING: $OVERLAY_FS/lib present but ignored (merged /usr); move to usr/lib/" >&2
  fi

  # SoC-thin overlay (e.g. mainserver.service) → SDK $CHIP/rootfs-overlay.
  # Separate BR2_ROOTFS_OVERLAY layer; chip last so it can override common.
  if [[ -d "$OVERLAY_CHIP_FS" ]]; then
    mkdir -p "$BR_CHIP_OVERLAY_ROOT"
    for sub in etc usr var; do
      if [[ -d "$OVERLAY_CHIP_FS/$sub" ]]; then
        mkdir -p "$BR_CHIP_OVERLAY_ROOT/$sub"
        if command -v rsync >/dev/null 2>&1; then
          rsync -a --delete "$OVERLAY_CHIP_FS/$sub/" "$BR_CHIP_OVERLAY_ROOT/$sub/"
        else
          rm -rf "$BR_CHIP_OVERLAY_ROOT/$sub"
          mkdir -p "$BR_CHIP_OVERLAY_ROOT/$sub"
          cp -a "$OVERLAY_CHIP_FS/$sub/." "$BR_CHIP_OVERLAY_ROOT/$sub/"
        fi
        echo "overlay: synced chip $BR_CHIP_OVERLAY_ROOT/$sub"
      fi
    done
    # Drop leftover OS trees from the pre-split chip overlay so they cannot
    # shadow common (chip layer is last). Keep system/ (LCD params).
    for sub in etc usr var opt lib; do
      if [[ ! -d "$OVERLAY_CHIP_FS/$sub" && -d "$BR_CHIP_OVERLAY_ROOT/$sub" ]]; then
        rm -rf "$BR_CHIP_OVERLAY_ROOT/$sub"
        echo "overlay: removed stale chip $BR_CHIP_OVERLAY_ROOT/$sub"
      fi
    done
  else
    echo "overlay: no SoC-thin overlay at $OVERLAY_CHIP_FS"
  fi

  local purge_src="$OVERLAY_COMMON/purge-retired-rootfs-artifacts.sh"
  if [[ -f "$purge_src" ]]; then
    sh "$purge_src" "$BR_OVERLAY_ROOT"
    echo "overlay: purged retired rootfs artifacts under $BR_OVERLAY_ROOT"
  fi
  rm -f \
    "$BR_OVERLAY_ROOT/usr/libexec/hmi/debug-boot.sh" \
    "$BR_OVERLAY_ROOT/usr/libexec/hmi/boot-kpi-watch.sh" \
    "$BR_OVERLAY_ROOT/usr/libexec/hmi/configure-camera-eth0.sh" \
    "$BR_OVERLAY_ROOT/usr/libexec/hmi/push-app-apply-and-restart.sh" \
    "$BR_OVERLAY_ROOT/usr/libexec/hmi/upgrade-app-apply-and-restart.sh"
}

sync_purge_retired_script() {
  local src="$LWS_OVERLAY_BOARD/purge-retired-rootfs-artifacts.sh"
  local dest="$BR_COMMON/lws-hmi/purge-retired-rootfs-artifacts.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip purge script sync" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_install_systemctl_wrapper_script() {
  local src="$LWS_OVERLAY_BOARD/install-systemctl-wrapper.sh"
  local dest="$BR_COMMON/lws-hmi/install-systemctl-wrapper.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip install-systemctl-wrapper sync" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_post_build_script() {
  local src="$LWS_OVERLAY_BOARD/post-build.sh"
  local dest="$BR_COMMON/lws-hmi/post-build.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip post-build script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_refresh_plan_a_systemd_wants_script() {
  local src="$LWS_OVERLAY_BOARD/refresh-plan-a-systemd-wants.sh"
  local dest="$BR_COMMON/lws-hmi/refresh-plan-a-systemd-wants.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip refresh-plan-a-systemd-wants script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_post_fakeroot_script() {
  local src="$LWS_OVERLAY_BOARD/post-fakeroot.sh"
  local dest="$BR_COMMON/lws-hmi/post-fakeroot.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip post-fakeroot script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_strip_fstab_script() {
  local src="$LWS_OVERLAY_BOARD/strip-fstab.sh"
  local dest="$BR_COMMON/lws-hmi/strip-fstab.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip strip-fstab script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_flutter_engine_script() {
  local src="$LWS_OVERLAY_BOARD/sync-flutter-engine.sh"
  local dest="$BR_COMMON/lws-hmi/sync-flutter-engine.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip flutter engine sync script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_flutter_elinux_script() {
  local src="$LWS_OVERLAY_BOARD/sync-flutter-embedded-linux.sh"
  local dest="$BR_COMMON/lws-hmi/sync-flutter-embedded-linux.sh"
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; skip flutter-elinux sync script" >&2
    return 0
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_buildroot_version_script() {
  local src="$LWS_OVERLAY_BOARD/sync-buildroot-version.sh"
  local dest="$BR_COMMON/lws-hmi/sync-buildroot-version.sh"
  if [[ ! -f "$src" ]]; then
    echo "ERROR: $src missing (required by post-build)" >&2
    return 1
  fi
  install -m 0755 "$src" "$dest"
  echo "overlay: $dest"
}

sync_kernel_board_dts() {
  local kernel_dts="$SDK/kernel/arch/arm64/boot/dts/rockchip"
  local overlay_dts="$OVERLAY/kernel/rockchip"
  local gen_script="$ROOT/scripts/gen-ynh960-panel-init-dtsi.sh"
  local f base

  if [[ ! -d "$kernel_dts" ]]; then
    echo "WARNING: $kernel_dts missing; skip board DTS sync" >&2
    return 0
  fi
  if [[ ! -d "$overlay_dts" ]]; then
    echo "WARNING: $overlay_dts missing; skip board DTS sync" >&2
    return 0
  fi

  [[ -x "$gen_script" ]] || chmod +x "$gen_script"
  bash "$gen_script"

  for f in "$overlay_dts"/*.dts "$overlay_dts"/*.dtsi; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    case "$base" in
    ek3562.md|*.md) continue ;;
    esac
    install_file "$f" "$kernel_dts/$base"
  done

  rm -f \
    "$kernel_dts/customer_board_ynh960.dtsi.orig" \
    "$kernel_dts/lws-hmi-ynh960-display.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-panel-init.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-linux-root.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-usb-gadget.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-usb-host.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-evb-trim.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-touch.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-own-gpio.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-uart5-gmac.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-uart7-pwm.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-uart-dma.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-npu-vop.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-mpp-dmc.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-rtc.dtsi" \
    "$kernel_dts/lws-hmi-ynh960-optee.dtsi"
  echo "overlay: synced board DTS/DTSI from $overlay_dts → $kernel_dts"
}

# Product vendor kernel drivers (git SoT under overlay/kernel/drivers/...; innohi retired).
# Drop vendor gpio_innohi tree and strip owned-SDK hooks that still pointed at it.
retire_kernel_innohi() {
  local kernel kconfig makefile
  kernel="$(kernel_source_dir)"
  kconfig="$kernel/Kconfig"
  makefile="$kernel/Makefile"

  [[ -d "$kernel" ]] || return 0

  rm -rf "$kernel/innohi"

  if [[ -f "$kconfig" ]] && grep -q 'source "innohi/Kconfig"' "$kconfig" 2>/dev/null; then
    # Remove the source line and a preceding blank line if present.
    python3 - "$kconfig" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
new = re.sub(r'\n*source "innohi/Kconfig"\n*', '\n\n', text, count=1)
if new != text:
    path.write_text(new)
    print(f"overlay: removed source \"innohi/Kconfig\" from {path}")
else:
    print(f"overlay: {path} already has no innohi/Kconfig source")
PY
  fi

  if [[ -f "$makefile" ]]; then
    python3 - "$makefile" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
orig = text
# Drop Innohi include path (headers were under kernel/innohi/inc).
text = re.sub(r'\n\t+-Iinnohi/inc \\\n', '\n', text)
# Owned tree used drivers-y := innohi/ solely for that subdir; clear it.
text = re.sub(
    r'(?m)^drivers-y\t:= innohi/\s*$',
    'drivers-y\t:=',
    text,
    count=1,
)
# distclean helper that only cleaned innohi/ objects — remove when tree is gone.
text = re.sub(
    r'\n\t@find innohi/ \\\( -name "\*\.o".*?\|xargs rm -rf\n',
    '\n',
    text,
    count=1,
    flags=re.S,
)
if text != orig:
    path.write_text(text)
    print(f"overlay: stripped innohi hooks from {path}")
else:
    print(f"overlay: {path} already has no innohi hooks")
PY
  fi

  echo "overlay: retired kernel/innohi (directory removed; Kconfig/Makefile hooks stripped)"
  # Drop any leftover LCD_PARAM_S stub from the Innohi bridge-pass experiment.
  rm -rf "$kernel/include/innohi"
}

sync_kernel_panel_simple() {
  local kernel src dst
  kernel="$(kernel_source_dir)"
  src="$OVERLAY/kernel/drivers/gpu/drm/panel/panel-simple.c"
  dst="$kernel/drivers/gpu/drm/panel/panel-simple.c"

  [[ -d "$kernel" ]] || return 0
  if [[ ! -f "$src" ]]; then
    echo "WARNING: $src missing; keep SDK panel-simple.c" >&2
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  install -m 0644 "$src" "$dst"
  echo "overlay: synced Rockchip panel-simple.c (no Innohi bridge/LCD_PARAM_S)"
}

sync_kernel_vendor_drivers() {
  local kernel src_aic dst_aic
  kernel="$(kernel_source_dir)"
  src_aic="$OVERLAY/kernel/drivers/net/wireless/aic8800"

  if [[ ! -d "$kernel" ]]; then
    echo "WARNING: $kernel missing; skip vendor driver sync" >&2
    return 0
  fi

  retire_kernel_innohi
  sync_kernel_panel_simple

  if [[ -d "$src_aic" ]]; then
    dst_aic="$kernel/drivers/net/wireless/aic8800"
    mkdir -p "$kernel/drivers/net/wireless"
    rsync -a --delete \
      --exclude='*.o' --exclude='*.ko' --exclude='*.mod' --exclude='*.mod.c' \
      "$src_aic/" "$dst_aic/"
    echo "overlay: synced aic8800 driver → $dst_aic"
  else
    echo "WARNING: $src_aic missing; skip aic8800 driver sync" >&2
  fi
}

sync_kernel_config_fragments() {
  local configs_dir="$SDK/kernel/arch/arm64/configs"
  if [[ ! -d "$configs_dir" ]]; then
    echo "WARNING: skip kernel config fragments" >&2
    return 0
  fi
  rm -f \
    "$configs_dir/lws-hmi-ynh960-display.config" \
    "$configs_dir/lws-hmi-ynh960-touch.config" \
    "$configs_dir/lws-hmi-ynh960-wifibt.config" \
    "$configs_dir/lws-hmi-kernel-trim.config" \
    "$configs_dir/lws-hmi-usb-gadget.config" \
    "$configs_dir/lws-hmi-bt-hid.config" \
    "$configs_dir/lws-hmi-debug-usb.config" \
    "$configs_dir/ynh960-virt-host.config"
  for cfg in "$OVERLAY/kernel/rockchip"/*.config; do
    [[ -f "$cfg" ]] || continue
    install_file "$cfg" "$configs_dir/$(basename "$cfg")"
  done
}

# Embed cfg80211 regulatory.db into the kernel Image (EXTRA_FIRMWARE_DIR=firmware).
# Built-in cfg80211 requests the DB before rootfs is mounted.
sync_kernel_firmware() {
  local kernel fw_src fw_dst f
  kernel="$(kernel_source_dir)"
  fw_src="$OVERLAY/kernel/firmware"
  fw_dst="$kernel/firmware"
  if [[ ! -d "$fw_src" ]]; then
    echo "WARNING: $fw_src missing; skip kernel firmware sync" >&2
    return 0
  fi
  mkdir -p "$fw_dst"
  for f in regulatory.db regulatory.db.p7s; do
    if [[ -f "$fw_src/$f" ]]; then
      install_file "$fw_src/$f" "$fw_dst/$f"
    else
      echo "WARNING: $fw_src/$f missing" >&2
    fi
  done
}

kernel_source_dir() {
  echo "$SDK/kernel"
}

apply_kernel_patches() {
  local kernel patch_dir relative target backup patch_file
  local -a patched_files=(
    "include/drm/drm_drv.h"
    "drivers/gpu/drm/drm_gem.c"
    "drivers/gpu/drm/rockchip/rockchip_drm_drv.c"
    "drivers/firmware/rockchip_sip.c"
    "drivers/gpu/arm/midgard/mali_malisw.h"
    "drivers/gpu/arm/bifrost/mali_malisw.h"
    "drivers/gpu/drm/rockchip/rockchip_post_csc.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.h"
    "drivers/net/phy/icplus.c"
    "drivers/pinctrl/pinctrl-rockchip.c"
    "drivers/mfd/rk808.c"
    "drivers/net/wireless/aic8800/aic8800_fdrv/rwnx_mod_params.c"
    # Restore from .lws-hmi.orig even with no active patch: keep vendor
    # `if (1) return -EINVAL` (PMIC RTC probe off). Do not re-add 0008.
    "drivers/rtc/rtc-rk808.c"
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
    # --forward skips already-applied hunks and exits 1; only exit ≥2 is fatal.
    set +e
    patch --batch --forward -d "$kernel" -p1 < "$patch_file"
    local st=$?
    set -e
    if [[ "$st" -gt 1 ]]; then
      echo "ERROR: kernel patch failed (exit $st): $(basename "$patch_file")" >&2
      return 1
    fi
    # Drop reject leftovers from already-applied hunks.
    find "$kernel" -name '*.rej' -delete 2>/dev/null || true
    echo "overlay: applied kernel patch $(basename "$patch_file")"
  done
}

restore_kernel_patches() {
  local kernel relative target backup
  local -a patched_files=(
    "include/drm/drm_drv.h"
    "drivers/gpu/drm/drm_gem.c"
    "drivers/gpu/drm/rockchip/rockchip_drm_drv.c"
    "drivers/firmware/rockchip_sip.c"
    "drivers/gpu/arm/midgard/mali_malisw.h"
    "drivers/gpu/arm/bifrost/mali_malisw.h"
    "drivers/gpu/drm/rockchip/rockchip_post_csc.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.c"
    "drivers/input/touchscreen/gt9xx/gt9xx.h"
    "drivers/net/phy/icplus.c"
    "drivers/pinctrl/pinctrl-rockchip.c"
    "drivers/mfd/rk808.c"
    "drivers/net/wireless/aic8800/aic8800_fdrv/rwnx_mod_params.c"
    "drivers/rtc/rtc-rk808.c"
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
  local lws_overlay_cfg="$OVERLAY/buildroot/${LWS_CHIP}_lws.config"
  if [[ -f "$lws_overlay_cfg" ]]; then
    install_file "$lws_overlay_cfg" "$BR_CHIPS_DIR/${LWS_CHIP}_lws.config"
  fi
  bash "$ROOT/scripts/generate-lws-hmi-defconfig.sh"
  local gen="$LWS_BR_DEFCONFIG_GEN"
  if [[ -f "$gen" ]]; then
    install_file "$gen" "$BR_DEFCONFIGS/$(basename "$LWS_BR_DEFCONFIG")"
  fi
}

sync_flutter_engine_package() {
  local src="$OVERLAY/buildroot/package/flutter-engine/flutter-engine.mk"
  local dot="$OVERLAY/buildroot/package/flutter-engine/dot-gclient"
  local patch_src="$OVERLAY/buildroot/package/flutter-engine"
  local stash="$BR_PKG_FLUTTER_ENGINE/$LWS_PREBUILT_PATCHES_DIR"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk" \
      "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk.orig"
  fi
  install_file "$src" "$BR_PKG_FLUTTER_ENGINE/flutter-engine.mk"
  if [[ -f "$dot" ]]; then
    install_file "$dot" "$BR_PKG_FLUTTER_ENGINE/dot-gclient"
  fi
  # Monorepo-era Buildroot patches (engine/src/… paths). Keep them in the
  # prebuilt-disabled stash so compile.mk can restore them; drop legacy paths.
  mkdir -p "$stash"
  rm -f "$BR_PKG_FLUTTER_ENGINE"/*.patch "$stash"/*.patch
  shopt -s nullglob
  local p
  for p in "$patch_src"/000*.patch; do
    install_file "$p" "$stash/$(basename "$p")"
  done
  shopt -u nullglob
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

sync_flutter_embedded_linux_package() {
  local src_mk="$OVERLAY/buildroot/package/flutter-embedded-linux/flutter-embedded-linux.mk"
  local src_cfg="$OVERLAY/buildroot/package/flutter-embedded-linux/Config.in"
  if [[ ! -f "$src_mk" ]]; then
    return 0
  fi
  mkdir -p "$BR_PKG_FLUTTER_ELINUX"
  if [[ -f "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk" && \
    ! -f "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk" \
      "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk.orig"
  fi
  if [[ -f "$BR_PKG_FLUTTER_ELINUX/Config.in" && \
    ! -f "$BR_PKG_FLUTTER_ELINUX/Config.in.orig" ]]; then
    cp -a "$BR_PKG_FLUTTER_ELINUX/Config.in" \
      "$BR_PKG_FLUTTER_ELINUX/Config.in.orig"
  fi
  install_file "$src_mk" "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk"
  if [[ -f "$src_cfg" ]]; then
    install_file "$src_cfg" "$BR_PKG_FLUTTER_ELINUX/Config.in"
  fi
  echo "overlay: flutter-embedded-linux prebuilt package synced"
}


# libserialport: overlay used to ship 0002-dont-check-termiox.patch for 0.1.1
# (termiox removed from Linux). Buildroot 2025.02.x ships 0.1.2 with that fix
# upstream — no overlay patch. Keep the sync no-op so old trees drop the file.
sync_libserialport_package() {
  local stale="$BR_PKG_LIBSERIALPORT/0002-dont-check-termiox.patch"
  if [[ -d "$BR_PKG_LIBSERIALPORT" && -f "$stale" ]]; then
    rm -f "$stale"
    echo "overlay: removed obsolete libserialport termiox patch (0.1.2+)"
  fi
}

# Upstream BlueZ Device1.Connect/Disconnect are empty-arg. Rockchip's
# 0001-bluez-modified-only-for-rockchip.patch breaks that D-Bus contract
# (Connect(s ADDR_TYPE)). Stash it so the product image builds stock 5.77.
sync_bluez5_utils_stock() {
  local pkg="$BR_PKG_BLUEZ5_UTILS"
  local patch="$pkg/0001-bluez-modified-only-for-rockchip.patch"
  local stash="$pkg/$LWS_ROCKCHIP_BLUEZ_PATCH_STASH"
  [[ -d "$pkg" ]] || {
    echo "overlay: skip bluez5_utils stock (package missing)" >&2
    return 0
  }
  if [[ -f "$patch" ]]; then
    mkdir -p "$stash"
    mv -f "$patch" "$stash/"
    echo "overlay: disabled Rockchip BlueZ patch (stock Device1 Connect/Disconnect)"
  elif [[ -f "$stash/0001-bluez-modified-only-for-rockchip.patch" ]]; then
    echo "overlay: Rockchip BlueZ patch already stashed (stock BlueZ)"
  else
    echo "overlay: no Rockchip BlueZ patch present (already stock)"
  fi
}

# BlueZ security pin (≥ 5.87). Replace Rockchip SDK 5.77 recipe; keep stock Device1
# (Rockchip Connect(s) patch stays stashed via sync_bluez5_utils_stock after this).
sync_bluez5_utils_package() {
  local src_dir="$OVERLAY/buildroot/package/bluez5_utils"
  local pkg="$BR_PKG_BLUEZ5_UTILS"
  local hdr_src="$OVERLAY/buildroot/package/bluez5_utils-headers"
  local hdr_pkg="$BR_PKG_BLUEZ5_UTILS_HEADERS"
  local stash="$pkg/$LWS_ROCKCHIP_BLUEZ_PATCH_STASH"
  if [[ ! -f "$src_dir/bluez5_utils.mk" ]]; then
    return 0
  fi
  if [[ ! -d "$pkg" ]]; then
    echo "overlay: skip bluez5_utils (package missing)" >&2
    return 0
  fi
  local base
  for base in bluez5_utils.mk bluez5_utils.hash Config.in S40bluetoothd; do
    if [[ -f "$pkg/$base" && ! -f "$pkg/$base.orig" ]]; then
      cp -a "$pkg/$base" "$pkg/$base.orig"
    fi
  done
  mkdir -p "$stash"
  shopt -s nullglob
  local moved=0
  local p
  for p in "$pkg"/*.patch; do
    mv "$p" "$stash/"
    moved=1
  done
  shopt -u nullglob
  if [[ "$moved" == 1 ]]; then
    echo "overlay: stashed SDK bluez5_utils patches (overlay BlueZ ≥ 5.87 recipe)"
  fi
  local f
  shopt -s nullglob
  for f in "$src_dir"/*; do
    [[ -f "$f" ]] || continue
    install_file "$f" "$pkg/$(basename "$f")"
  done
  shopt -u nullglob
  if [[ -f "$hdr_src/bluez5_utils-headers.mk" && -d "$hdr_pkg" ]]; then
    for base in bluez5_utils-headers.mk bluez5_utils-headers.hash Config.in; do
      if [[ -f "$hdr_pkg/$base" && ! -f "$hdr_pkg/$base.orig" ]]; then
        cp -a "$hdr_pkg/$base" "$hdr_pkg/$base.orig"
      fi
    done
    for f in "$hdr_src"/*; do
      [[ -f "$f" ]] || continue
      install_file "$f" "$hdr_pkg/$(basename "$f")"
    done
  fi
  local ver
  ver="$(grep -E '^BLUEZ5_UTILS_VERSION' "$pkg/bluez5_utils.mk" | awk '{print $3}')"
  echo "overlay: bluez5_utils package synced (BLUEZ5_UTILS_VERSION=${ver:-unknown})"
}

restore_bluez5_utils_rockchip_patch() {
  local pkg="$BR_PKG_BLUEZ5_UTILS"
  local stash="$pkg/$LWS_ROCKCHIP_BLUEZ_PATCH_STASH"
  local stashed="$stash/0001-bluez-modified-only-for-rockchip.patch"
  [[ -f "$stashed" ]] || return 0
  mv -f "$stashed" "$pkg/"
  rmdir "$stash" 2>/dev/null || true
  echo "overlay: restored Rockchip BlueZ patch for bluez5_utils"
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
  local br_pkg_cfg="$SDK/buildroot/package/Config.in"
  local source_line='	source "package/source-han-sans/Config.in"'
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -d "$SDK/buildroot/package/source-han-sans" ]]; then
    echo "WARNING: overlay source-han-sans-cn.mk present but SDK package/source-han-sans missing" >&2
    return 0
  fi
  if [[ ! -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" ]]; then
    cp -a "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk" \
      "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig"
  fi
  install_file "$src" "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk"

  # Vendor package tree exists under package/source-han-sans/, but stock
  # Buildroot 2025.02 package/Config.in does not source it — then
  # BR2_PACKAGE_SOURCE_HAN_SANS_CN=y is dropped by olddefconfig and the
  # rootfs ships DejaVu only (CJK tofu). Re-wire into the Fonts menu.
  if [[ -f "$br_pkg_cfg" ]] && ! grep -qF 'package/source-han-sans/Config.in' "$br_pkg_cfg"; then
    if grep -qF 'package/wqy-zenhei/Config.in' "$br_pkg_cfg"; then
      # Insert after wqy-zenhei (last stock font entry in Fonts comment).
      local tmp
      tmp="$(mktemp)"
      awk -v line="$source_line" '
        { print }
        $0 ~ /package\/wqy-zenhei\/Config\.in/ && !done {
          print line
          done=1
        }
      ' "$br_pkg_cfg" >"$tmp"
      mv -f "$tmp" "$br_pkg_cfg"
      echo "overlay: wired package/source-han-sans into package/Config.in"
    else
      echo "WARNING: could not wire source-han-sans (wqy-zenhei anchor missing in package/Config.in)" >&2
    fi
  fi
}

# GStreamer 1.28.5 needs host Meson ≥ 1.4; SDK ships 1.3.1.
# Rockchip meson patches target 1.3.x — stash them when applying the overlay pin.
sync_meson_package() {
  local src_dir="$OVERLAY/buildroot/package/meson"
  local pkg="$BR_PKG_MESON"
  local stash="$pkg/$LWS_ROCKCHIP_MESON_PATCH_STASH"
  if [[ ! -f "$src_dir/meson.mk" ]]; then
    return 0
  fi
  if [[ ! -d "$pkg" ]]; then
    echo "overlay: skip meson (package missing)" >&2
    return 0
  fi
  if [[ -f "$pkg/meson.mk" && ! -f "$pkg/meson.mk.orig" ]]; then
    cp -a "$pkg/meson.mk" "$pkg/meson.mk.orig"
  fi
  if [[ -f "$pkg/meson.hash" && ! -f "$pkg/meson.hash.orig" ]]; then
    cp -a "$pkg/meson.hash" "$pkg/meson.hash.orig"
  fi
  install_file "$src_dir/meson.mk" "$pkg/meson.mk"
  install_file "$src_dir/meson.hash" "$pkg/meson.hash"
  mkdir -p "$stash"
  shopt -s nullglob
  local moved=0
  local p
  for p in "$pkg"/*.patch; do
    mv "$p" "$stash/"
    moved=1
  done
  shopt -u nullglob
  if [[ "$moved" == 1 ]]; then
    echo "overlay: stashed Rockchip meson patches (overlay Meson ≥ 1.4)"
  fi
  echo "overlay: meson package synced ($(grep -E '^MESON_VERSION' "$pkg/meson.mk" | awk '{print $3}'))"
}

# systemd + Rockchip GCC 10.3 UAPI 4.20: keep networkd selectable while the
# external toolchain truthfully reports 4.20, and ship sockios *_OLD compat so
# networkd compiles against that UAPI.
sync_systemd_package() {
  local sockios_src="$OVERLAY/buildroot/package/systemd/0003-basic-linux-sockios-compat-old-uapi.patch"
  local pkg="$BR_PKG_SYSTEMD"
  if [[ ! -d "$pkg" ]]; then
    echo "overlay: skip systemd patches (package missing)" >&2
    return 0
  fi
  local stale_config_patch="$pkg/0002-config-allow-networkd-with-rockchip-4.20-uapi.patch"
  if [[ -f "$stale_config_patch" ]]; then
    rm -f "$stale_config_patch"
    echo "overlay: removed stale systemd Config.in patch from package patch dir"
  fi

  local config="$pkg/Config.in"
  if [[ -f "$config" ]]; then
    perl -0pi -e 's/\tdefault y if BR2_TOOLCHAIN_HEADERS_AT_LEAST_5_4\n\tdepends on BR2_TOOLCHAIN_HEADERS_AT_LEAST_5_4\n/\tdefault y\n/s' "$config"
    perl -0pi -e 's/\ncomment "systemd-networkd needs a toolchain (?:w\/|with kernel) headers >= 5\.4"\n\tdepends on !BR2_TOOLCHAIN_HEADERS_AT_LEAST_5_4\n//s' "$config"
    echo "overlay: systemd Config.in networkd header gate relaxed"
  fi

  local mk="$pkg/systemd.mk"
  local version=""
  local major=""
  if [[ -f "$mk" ]]; then
    version="$(sed -n 's/^SYSTEMD_VERSION[[:space:]]*=[[:space:]]*//p' "$mk" | head -1)"
    major="${version%%.*}"
  fi
  if [[ -f "$sockios_src" && "$major" =~ ^[0-9]+$ && "$major" -ge 256 ]]; then
    install_file "$sockios_src" "$pkg/0003-basic-linux-sockios-compat-old-uapi.patch"
    echo "overlay: systemd sockios UAPI compat patch synced (systemd $version)"
  else
    rm -f "$pkg/0003-basic-linux-sockios-compat-old-uapi.patch"
    if [[ -n "$version" ]]; then
      echo "overlay: systemd sockios UAPI compat patch skipped (systemd $version)"
    fi
  fi
}

# OpenSSL CVE pin (3.5.7 LTS). Replace Rockchip SDK 3.2.1 recipe; stash vendor patches
# (stock BR reproducible/static/ppc — overlay ships Buildroot 2025.02.x set for 3.5.7).
sync_libopenssl_package() {
  local src_dir="$OVERLAY/buildroot/package/libopenssl"
  local pkg="$BR_PKG_LIBOPENSSL"
  local stash="$pkg/$LWS_ROCKCHIP_OPENSSL_PATCH_STASH"
  if [[ ! -f "$src_dir/libopenssl.mk" ]]; then
    return 0
  fi
  if [[ ! -d "$pkg" ]]; then
    echo "overlay: skip libopenssl (package missing)" >&2
    return 0
  fi
  local base
  for base in libopenssl.mk libopenssl.hash Config.in; do
    if [[ -f "$pkg/$base" && ! -f "$pkg/$base.orig" ]]; then
      cp -a "$pkg/$base" "$pkg/$base.orig"
    fi
  done
  mkdir -p "$stash"
  shopt -s nullglob
  local moved=0
  local p
  for p in "$pkg"/*.patch; do
    mv "$p" "$stash/"
    moved=1
  done
  shopt -u nullglob
  if [[ "$moved" == 1 ]]; then
    echo "overlay: stashed SDK libopenssl patches (overlay OpenSSL 3.5.x recipe)"
  fi
  local f
  shopt -s nullglob
  for f in "$src_dir"/*; do
    [[ -f "$f" ]] || continue
    install_file "$f" "$pkg/$(basename "$f")"
  done
  shopt -u nullglob
  local ver
  ver="$(grep -E '^LIBOPENSSL_VERSION' "$pkg/libopenssl.mk" | awk '{print $3}')"
  echo "overlay: libopenssl package synced (LIBOPENSSL_VERSION=${ver:-unknown})"
}

# Product GStreamer pin (1.28.5+). Sync recipe files and stash Rockchip 1.22.x patches
# that do not apply to the locked tip (MPP path lives in gstreamer1-rockchip).
sync_gstreamer1_package() {
  local src_root="$OVERLAY/buildroot/package/gstreamer1"
  local pkg_root="$BR_PKG_GSTREAMER1"
  if [[ ! -d "$src_root" ]]; then
    return 0
  fi
  if [[ ! -d "$pkg_root" ]]; then
    echo "overlay: skip gstreamer1 (package tree missing)" >&2
    return 0
  fi
  local pkg
  for pkg in gstreamer1 gst1-plugins-base gst1-plugins-good gst1-plugins-bad; do
    local src="$src_root/$pkg"
    local dst="$pkg_root/$pkg"
    if [[ ! -d "$src" || ! -d "$dst" ]]; then
      echo "overlay: skip gstreamer1/$pkg (src or dst missing)" >&2
      continue
    fi
    local f
    shopt -s nullglob
    for f in "$src"/*; do
      local base
      base="$(basename "$f")"
      case "$base" in
        *.patch) continue ;;
      esac
      if [[ -f "$dst/$base" && ! -f "$dst/$base.orig" ]]; then
        case "$base" in
          *.mk|Config.in|gst.sh) cp -a "$dst/$base" "$dst/$base.orig" ;;
        esac
      fi
      install_file "$f" "$dst/$base"
    done
    shopt -u nullglob
    local stash="$dst/$LWS_ROCKCHIP_GST_PATCH_STASH"
    mkdir -p "$stash"
    local moved=0
    shopt -s nullglob
    for f in "$dst"/*.patch; do
      mv "$f" "$stash/"
      moved=1
    done
    shopt -u nullglob
    if [[ "$moved" == 1 ]]; then
      echo "overlay: stashed Rockchip patches for gstreamer1/$pkg (1.28 tip)"
    fi
  done
  local ver
  ver="$(grep -E '^GSTREAMER1_VERSION' "$pkg_root/gstreamer1/gstreamer1.mk" | awk '{print $3}')"
  echo "overlay: gstreamer1 family synced (GSTREAMER1_VERSION=${ver:-unknown})"
}

# Force -Drga=enabled for mppvideodec RGBA/scale (see package comment).
sync_gstreamer1_rockchip_package() {
  local src="$OVERLAY/buildroot/package/rockchip/gstreamer1-rockchip/gstreamer1-rockchip.mk"
  local dst="$SDK/buildroot/package/rockchip/gstreamer1-rockchip/gstreamer1-rockchip.mk"
  if [[ ! -f "$src" ]]; then
    return 0
  fi
  if [[ ! -f "$dst" ]]; then
    echo "overlay: skip gstreamer1-rockchip (package missing)" >&2
    return 0
  fi
  if [[ ! -f "${dst}.orig" ]]; then
    cp -a "$dst" "${dst}.orig"
  fi
  install_file "$src" "$dst"
  echo "overlay: gstreamer1-rockchip.mk synced (RGA always enabled)"
}

sync_boot_logo() {
  local kernel_dir="$SDK/kernel"
  if [[ ! -d "$kernel_dir" ]]; then
    echo "WARNING: $kernel_dir missing; skip boot logo install" >&2
    return 0
  fi
  if [[ ! -f "$BOARD_DIR/logo/logo.bmp" || ! -f "$BOARD_DIR/logo/logo_kernel.bmp" ]]; then
    echo "overlay: skip boot logo install (run make build-boot-logo first)" >&2
    return 0
  fi
  install_file "$BOARD_DIR/logo/logo.bmp" "$kernel_dir/logo.bmp"
  install_file "$BOARD_DIR/logo/logo_kernel.bmp" "$kernel_dir/logo_kernel.bmp"
}

sync_display_params() {
  # Do not stage ParamUpdate LCD tables into chip overlay /system/etc.
  mkdir -p "$BR_OVERLAY"
  rm -f \
    "$BR_OVERLAY/960_lcd_param_rk356x.txt" \
    "$BR_OVERLAY/lcd_mipi_param.txt" \
    "$BR_OVERLAY/LCD_PARAM_RK356X_V11_0.txt"
  echo "overlay: skip /system/etc LCD params (panel timing is kernel DT)"
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
  echo "overlay: mk-loader.sh → Innohi prebuilt loader"
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

patch_mk_kernel() {
  local target="$SCRIPTS_DIR/mk-kernel.sh"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip mk-kernel patch" >&2
    return 0
  fi
  backup_sdk_script "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/patch-mk-kernel.sh" \
    "$(sdk_realpath "$target")"
  echo "overlay: patched $(basename "$(sdk_realpath "$target")") (canonical kernel/ layout)"
}

patch_mk_rootfs() {
  local target="$SCRIPTS_DIR/mk-rootfs.sh"
  if [[ ! -f "$target" ]]; then
    echo "WARNING: $target missing; skip mk-rootfs patch" >&2
    return 0
  fi
  backup_sdk_script "$target"
  bash "$OVERLAY/device/rockchip/common/scripts/patch-mk-rootfs.sh" \
    "$(sdk_realpath "$target")"
  echo "overlay: patched $(basename "$(sdk_realpath "$target")") (CROOT / defconfig)"
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
    echo "overlay: 30-rootfs.sh → mk-rootfs.sh (same file; skip retired MainServer patch)"
    return 0
  fi
  echo "overlay: skip 30-rootfs MainServer patch (retired)"
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
  bash "$OVERLAY/device/rockchip/common/scripts/patch-post-wifibt.sh" \
    "$target"
  echo "overlay: patched $target (CROOT + OEM radio; no Innohi FW dump)"
}

patch_buildroot_config() {
  purge_legacy_fs_overlay
  local common_line='BR2_ROOTFS_OVERLAY+="board/rockchip/common/rootfs-overlay/"'
  local chip_line="BR2_ROOTFS_OVERLAY+=\"board/rockchip/${LWS_CHIP}/rootfs-overlay/\""
  if [[ ! -f "$BR_CONFIG" ]]; then
    echo "WARNING: $BR_CONFIG missing; skip BR2_ROOTFS_OVERLAY patch" >&2
    return 0
  fi
  if [[ ! -f "$BR_CONFIG.orig" ]]; then
    cp -a "$BR_CONFIG" "$BR_CONFIG.orig"
  fi
  # Rewrite our += lines in order (common then chip). Exact-match only so a
  # vendor BR2_ROOTFS_OVERLAY="…base …fs-overlay…" assignment is left intact.
  sed -i.bak \
    -e '/^BR2_ROOTFS_OVERLAY+="board\/rockchip\/common\/rootfs-overlay\/"$/d' \
    -e "/^BR2_ROOTFS_OVERLAY+=\"board\/rockchip\/${LWS_CHIP}\/rootfs-overlay\/\"$/d" \
    "$BR_CONFIG"
  rm -f "$BR_CONFIG.bak"
  echo "$common_line" >> "$BR_CONFIG"
  echo "$chip_line" >> "$BR_CONFIG"
  echo "overlay: set common then chip BR2_ROOTFS_OVERLAY in $BR_CONFIG"
}

restore_check_sdk=0
restore_all=0
platform_squash_only=0
if [[ "${1:-}" == "--restore-check-sdk" ]]; then
  restore_check_sdk=1
elif [[ "${1:-}" == "--restore" ]]; then
  restore_all=1
elif [[ "${1:-}" == "--platform-squash" ]]; then
  platform_squash_only=1
fi

# Owned tree (W3): skip re-applying kernel *patches* + stable device script
# patches unless forced. DTS + arch/arm64/configs fragments from
# overlay/kernel/ still sync every apply (e.g. CONFIG_SND_VIRTIO for P3.2).
skip_platform_overlay=0
if [[ "$platform_squash_only" != "1" \
   && -f "$SDK/.lws-owned-tree" \
   && "${FORCE_PLATFORM_OVERLAY:-0}" != "1" ]]; then
  skip_platform_overlay=1
fi

run_platform_overlay() {
  sync_kernel_board_dts
  sync_kernel_vendor_drivers
  sync_kernel_config_fragments
  sync_kernel_firmware
  apply_kernel_patches
  patch_mk_kernel
  patch_mk_loader
  patch_mk_rootfs
  patch_30_rootfs
  patch_post_wifibt
  fix_innohi_scripts_buildroot_output_dir
}

# Always refresh overlay/kernel SoT into the SDK (safe on owned tree).
sync_kernel_overlay_sources() {
  sync_kernel_board_dts
  sync_kernel_vendor_drivers
  sync_kernel_config_fragments
  sync_kernel_firmware
}

if [[ "$platform_squash_only" == "1" ]]; then
  run_platform_overlay
  echo "ynh960 platform squash applied to SDK (kernel + device patches only)"
  exit 0
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
    rm -f "$POST_HOOKS_DIR/05-display.sh"
    rm -f "$POST_HOOKS_DIR/06-systemd.sh"
    rm -f "$POST_HOOKS_DIR/07-innohi-display-bin.sh"
    rm -f "$POST_HOOKS_DIR/08-systemd-finalize.sh"
    rm -f "$POST_HOOKS_DIR/09-wifibt-innohi.sh"
    rm -f "$POST_HOOKS_DIR/31-strip-fstab.sh"
    rm -f "$POST_HOOKS_DIR/91-weston-ini.sh"
    rm -rf "$BR_BOARD/rootfs-overlay"
    rm -rf "$BR_COMMON/rootfs-overlay"
    rm -rf "$BR_COMMON/lws-hmi"
    rm -rf "$BR_COMMON/lws-hmi-prebuilt-gstreamer" "$BR_COMMON/lws-hmi-prebuilt-platform"
    for f in lws_hmi_base.config lws_hmi_systemd.config lws_hmi_network.config lws_hmi_npu.config lws_hmi_flutter_weston.config lws_hmi_wayland.config lws_hmi_font.config lws_hmi_bt.config lws_hmi_gst_rtsp.config lws_hmi_optee.config lws_hmi_build.config lws_hmi_toolchain_external.config lws_hmi_gst_prebuilt.config lws_hmi_platform_prebuilt.config; do
      rm -f "$BR_CHIPS_DIR/$f"
    done
    rm -f "$BR_CHIPS_DIR/${LWS_CHIP}_lws.config"
    for f in "$(basename "$LWS_BR_DEFCONFIG")"; do
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
    if [[ -f "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk.orig" ]]; then
      mv -f "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk.orig" \
        "$BR_PKG_FLUTTER_ELINUX/flutter-embedded-linux.mk"
      echo "restored upstream flutter-embedded-linux.mk"
    fi
    if [[ -f "$BR_PKG_FLUTTER_ELINUX/Config.in.orig" ]]; then
      mv -f "$BR_PKG_FLUTTER_ELINUX/Config.in.orig" \
        "$BR_PKG_FLUTTER_ELINUX/Config.in"
      echo "restored upstream flutter-embedded-linux Config.in"
    fi
    restore_bluez5_utils_rockchip_patch
    if [[ -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" ]]; then
      mv -f "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk.orig" \
        "$BR_PKG_SOURCE_HAN_SANS_CN/source-han-sans-cn.mk"
      echo "restored upstream source-han-sans-cn.mk"
    fi
    rm -f "$SDK/kernel/logo.bmp" "$SDK/kernel/logo_kernel.bmp"
    for kernel_dts in "$SDK/kernel/arch/arm64/boot/dts/rockchip"; do
      rm -f \
        "$kernel_dts/customer_board_ynh960.dtsi.orig" \
        "$kernel_dts/lws-hmi-ynh960-display.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-linux-root.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-usb-gadget.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-usb-host.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-evb-trim.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-touch.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-own-gpio.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-uart5-gmac.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-uart7-pwm.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-uart-dma.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-npu-vop.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-mpp-dmc.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-panel-init.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-rtc.dtsi" \
        "$kernel_dts/lws-hmi-ynh960-optee.dtsi" \
        "$kernel_dts/ynh960.dts" \
        "$kernel_dts/customer_board_ynh960.dtsi" \
        "$kernel_dts/ynh960-display.dtsi" \
        "$kernel_dts/ynh960-linux-root.dtsi" \
        "$kernel_dts/ynh960-usb-gadget.dtsi" \
        "$kernel_dts/ynh960-usb-host.dtsi" \
        "$kernel_dts/ynh960-evb-trim.dtsi" \
        "$kernel_dts/ynh960-touch.dtsi" \
        "$kernel_dts/ynh960-own-gpio.dtsi" \
        "$kernel_dts/ynh960-uart5-gmac.dtsi" \
        "$kernel_dts/ynh960-uart7-pwm.dtsi" \
        "$kernel_dts/ynh960-uart-dma.dtsi" \
        "$kernel_dts/ynh960-npu-vop.dtsi" \
        "$kernel_dts/ynh960-mpp-dmc.dtsi" \
        "$kernel_dts/ynh960-panel-init.dtsi" \
        "$kernel_dts/ynh960-rtc.dtsi" \
        "$kernel_dts/ynh960-optee.dtsi"
      echo "removed overlay-synced board DTS from $kernel_dts"
    done
    rm -f "$SDK/kernel/firmware/regulatory.db" "$SDK/kernel/firmware/regulatory.db.p7s"
    restore_kernel_patches
    echo "removed lws-hmi buildroot overlay + post-hooks + chip configs"
  fi
  exit 0
fi

# Drop mistaken app bundles before syncing etc/usr/var (never part of git fs-overlay).
purge_stale_fs_overlay_opt

install_file "$BOARD_DIR/ynh960_defconfig" "$CHIP_DIR/ynh960_defconfig"
install_file "$BOARD_DIR/ynh960_defconfig" "$CHIPS_DIR/ynh960_defconfig"

# Avahi users table for prebuilt platform path.
# BR2_ROOTFS_USERS_TABLES paths are relative to the Buildroot topdir (buildroot/),
# same as BR2_ROOTFS_OVERLAY — not device/rockchip/.
AVAHI_USERS_SRC="$OVERLAY_COMMON/avahi.users"
AVAHI_USERS_DST="$BR_COMMON/lws-hmi/avahi.users"
if [[ -f "$AVAHI_USERS_SRC" ]]; then
  install_file "$AVAHI_USERS_SRC" "$AVAHI_USERS_DST"
fi
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIP_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/960_lcd_param_rk356x.txt" "$CHIPS_DIR/960_lcd_param_rk356x.txt"
install_file "$BOARD_DIR/parameter-buildroot-fit.txt" "$CHIP_DIR/parameter-buildroot-fit.txt"
install_file "$BOARD_DIR/parameter-buildroot-fit.txt" "$CHIPS_DIR/parameter-buildroot-fit.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-gpt.txt" "$CHIP_DIR/parameter-ynh960-android-gpt.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-gpt.txt" "$CHIPS_DIR/parameter-ynh960-android-gpt.txt"
install_file "$BOARD_DIR/parameter-ynh960-android-stock.txt" "$CHIP_DIR/parameter-ynh960-android-stock.txt"
install_file "$BOARD_DIR/boot-slim.its" "$CHIP_DIR/boot-slim.its"
install_file "$BOARD_DIR/boot-slim.its" "$CHIPS_DIR/boot-slim.its"
# W5 multi-conf ITS (inventory → generate → install). Active via RK_BOOT_FIT_ITS_NAME.
bash "$ROOT/scripts/generate-boot-fit-its.sh" \
	"$BOARD_DIR/rk356x-fit-boards.txt" "$BOARD_DIR/boot-multi.its"
install_file "$BOARD_DIR/boot-multi.its" "$CHIP_DIR/boot-multi.its"
install_file "$BOARD_DIR/boot-multi.its" "$CHIPS_DIR/boot-multi.its"
install_file "$BOARD_DIR/rk356x-fit-boards.txt" "$CHIP_DIR/rk356x-fit-boards.txt"
install_file "$BOARD_DIR/rk356x-fit-boards.txt" "$CHIPS_DIR/rk356x-fit-boards.txt"
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

install_file "$OVERLAY/device/rockchip/common/post-hooks/05-display.sh" \
  "$POST_HOOKS_DIR/05-display.sh"
chmod +x "$POST_HOOKS_DIR/05-display.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/06-systemd.sh" \
  "$POST_HOOKS_DIR/06-systemd.sh"
chmod +x "$POST_HOOKS_DIR/06-systemd.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/07-innohi-display-bin.sh" \
  "$POST_HOOKS_DIR/07-innohi-display-bin.sh"
chmod +x "$POST_HOOKS_DIR/07-innohi-display-bin.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/08-systemd-finalize.sh" \
  "$POST_HOOKS_DIR/08-systemd-finalize.sh"
chmod +x "$POST_HOOKS_DIR/08-systemd-finalize.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/09-wifibt-innohi.sh" \
  "$POST_HOOKS_DIR/09-wifibt-innohi.sh"
chmod +x "$POST_HOOKS_DIR/09-wifibt-innohi.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/31-strip-fstab.sh" \
  "$POST_HOOKS_DIR/31-strip-fstab.sh"
chmod +x "$POST_HOOKS_DIR/31-strip-fstab.sh"

install_file "$OVERLAY/device/rockchip/common/post-hooks/91-weston-ini.sh" \
  "$POST_HOOKS_DIR/91-weston-ini.sh"
chmod +x "$POST_HOOKS_DIR/91-weston-ini.sh"

# Rockchip 90-overlay rsyncs common/overlays/10-weston over BR2_ROOTFS_OVERLAY.
# Keep that source in sync so stock weston.ini is landscape even without 91-*.
WESTON_INI_SRC="$OVERLAY_FS/etc/xdg/weston/weston.ini"
WESTON_INI_RK="$SDK/buildroot/board/rockchip/common/overlays/10-weston/etc/xdg/weston/weston.ini"
if [[ -f "$WESTON_INI_SRC" && -d "$(dirname "$WESTON_INI_RK")" ]]; then
  install_file "$WESTON_INI_SRC" "$WESTON_INI_RK"
fi

sync_fs_overlay
mkdir -p "$BR_COMMON/lws-hmi"
sync_purge_retired_script
sync_install_systemctl_wrapper_script
sync_post_build_script
sync_refresh_plan_a_systemd_wants_script
sync_post_fakeroot_script
sync_strip_fstab_script
sync_flutter_engine_script
sync_flutter_elinux_script
sync_buildroot_version_script
if [[ "$skip_platform_overlay" == "1" ]]; then
  echo "overlay: skip platform kernel/device patches (.lws-owned-tree present; FORCE_PLATFORM_OVERLAY=1 to re-apply)"
  sync_kernel_overlay_sources
  patch_mk_kernel
else
  run_platform_overlay
fi
sync_display_params
sync_boot_logo
sync_buildroot_chip_configs
sync_flutter_engine_package
sync_flutter_sdk_package
sync_flutter_embedded_linux_package
sync_libserialport_package
sync_bluez5_utils_package
sync_bluez5_utils_stock
sync_bluez_alsa_package
sync_source_han_sans_cn_package
sync_meson_package
sync_systemd_package
sync_libopenssl_package
sync_gstreamer1_package
sync_gstreamer1_rockchip_package
patch_buildroot_config
bash "$ROOT/scripts/normalize-innohi-sdk.sh"
bash "$ROOT/scripts/sync-prebuilt-overlays.sh"

echo "ynh960 board + display + Plan A systemd overlay applied to SDK"
