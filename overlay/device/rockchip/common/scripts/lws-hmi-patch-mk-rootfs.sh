#!/usr/bin/env bash
# Fix Innohi mk-rootfs.sh using empty CROOT (Buildroot var) instead of RK_SDK_DIR.
set -euo pipefail

target="$1"
marker='lws-hmi: mk-rootfs CROOT fix'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

old_head = """#!/bin/bash -e

export UBUNTU_NAME=rootfs-ubuntu22.04-xfce
export MOUNT_ROOTFS_IMG=${CROOT}/ubuntu/$UBUNTU_NAME.img
export RK_KERNEL_DTS_NAME=`cat ${CROOT}/device/rockchip/.chips/rk3566_rk3568/$RK_DEFCONFIG |grep RK_KERNEL_DTS_NAME | awk -F'"' '{print $2}'`"""

new_head = """#!/bin/bash -e

# lws-hmi: mk-rootfs CROOT fix
RK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
RK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"
CROOT="${CROOT:-$RK_SDK_DIR}"

lws_hmi_defconfig_cfg() {
	local defconfig="${1:-$RK_DEFCONFIG}"
	[ -n "$defconfig" ] || return 1
	local chip="${RK_CHIP:-rk3566_rk3568}"
	local cfg="$RK_SDK_DIR/device/rockchip/.chips/$chip/$defconfig"
	[ -r "$cfg" ] || cfg="$RK_SDK_DIR/device/rockchip/.chip/$defconfig"
	[ -r "$cfg" ] || return 1
	echo "$cfg"
}

lws_hmi_defconfig_var() {
	local key="$1"
	local cfg
	cfg="$(lws_hmi_defconfig_cfg)" || return 0
	grep "^${key}=" "$cfg" | head -1 | awk -F'"' '{print $2}'
}

export UBUNTU_NAME=rootfs-ubuntu22.04-xfce
export MOUNT_ROOTFS_IMG=${CROOT}/ubuntu/$UBUNTU_NAME.img
RK_KERNEL_DTS_NAME="${RK_KERNEL_DTS_NAME:-$(lws_hmi_defconfig_var RK_KERNEL_DTS_NAME)}"
export RK_KERNEL_DTS_NAME"""

if old_head not in text:
    sys.stderr.write(f"ERROR: unexpected mk-rootfs.sh header in {path}\n")
    sys.exit(1)

text = text.replace(old_head, new_head, 1)

old_lcd = "\tDEFAULT_LCD_PARAM=`cat ${CROOT}/device/rockchip/.chips/rk3566_rk3568/$RK_DEFCONFIG |grep DEFAULT_LCD_PARAM | awk -F'\"' '{print $2}'`\n\techo \"=================== DEFAULT_LCD_PARAM $DEFAULT_LCD_PARAM=============================\"\n\tsudo cp -rf ${CROOT}/device/rockchip/.chips/rk3566_rk3568/$DEFAULT_LCD_PARAM  ${CROOT}/binary/system/etc/LCD_PARAM_RK356X_V11_0.txt"

new_lcd = "\tDEFAULT_LCD_PARAM=\"${DEFAULT_LCD_PARAM:-$(lws_hmi_defconfig_var DEFAULT_LCD_PARAM)}\"\n\techo \"=================== DEFAULT_LCD_PARAM $DEFAULT_LCD_PARAM=============================\"\n\tif [ -n \"$DEFAULT_LCD_PARAM\" ]; then\n\t\tLCD_SRC=\"$(dirname \"$(lws_hmi_defconfig_cfg)\")/$DEFAULT_LCD_PARAM\"\n\t\tsudo cp -rf \"$LCD_SRC\" ${CROOT}/binary/system/etc/LCD_PARAM_RK356X_V11_0.txt\n\tfi"

if old_lcd not in text:
    sys.stderr.write(f"WARNING: mk-rootfs LCD block not found in {path}; header patch only\n")
else:
    text = text.replace(old_lcd, new_lcd, 1)

innohi_block = """\t\t
##############拷贝开机服务###############################################\t
\tcd ${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target
\tsudo cp -rf ${CROOT}/innohi_board/rootfs/usr/bin/MainServer  usr/bin/
\tsudo cp -rf ${CROOT}/innohi_board/rootfs/usr/bin/ParamUpdate  usr/bin/
\tsudo echo "#! /bin/sh" > etc/init.d/S99-init.sh
\techo "/usr/bin/rk_wifi_init /dev/ttyS1 &" >> etc/init.d/S99-init.sh
\tsudo echo "/usr/bin/MainServer &" >> etc/init.d/S99-init.sh
\tsudo chown $USER:$USER . -R
\tcd -;
\tcp -rf ${CROOT}/innohi_board/rootfs/usr/bin/*  ${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target/usr/bin/
\t
\t####再编译一次，打包innohi rootfs#####
\t"$RK_SCRIPTS_DIR/mk-buildroot.sh" $RK_BUILDROOT_CFG "$IMAGE_DIR"
\t\t
#############################################################"""

innohi_guarded = """\t\t
# lws-hmi: Plan A (systemd + flutter-pi) skips Innohi MainServer/S99-init rebuild.
if [[ "${RK_BUILDROOT_CFG:-}" != *lws_hmi* ]]; then
##############拷贝开机服务###############################################\t
\tcd ${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target
\tsudo cp -rf ${CROOT}/innohi_board/rootfs/usr/bin/MainServer  usr/bin/
\tsudo cp -rf ${CROOT}/innohi_board/rootfs/usr/bin/ParamUpdate  usr/bin/
\tsudo echo "#! /bin/sh" > etc/init.d/S99-init.sh
\techo "/usr/bin/rk_wifi_init /dev/ttyS1 &" >> etc/init.d/S99-init.sh
\tsudo echo "/usr/bin/MainServer &" >> etc/init.d/S99-init.sh
\tsudo chown $USER:$USER . -R
\tcd -;
\tcp -rf ${CROOT}/innohi_board/rootfs/usr/bin/*  ${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target/usr/bin/
\t
\t####再编译一次，打包innohi rootfs#####
\t"$RK_SCRIPTS_DIR/mk-buildroot.sh" $RK_BUILDROOT_CFG "$IMAGE_DIR"
fi
\t\t
#############################################################"""

if innohi_block in text:
    text = text.replace(innohi_block, innohi_guarded, 1)
else:
    sys.stderr.write(f"WARNING: mk-rootfs Innohi MainServer block not found in {path}\n")

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
