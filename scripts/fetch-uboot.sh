#!/usr/bin/env bash
# Fetch Rockchip U-Boot sources into SDK (Innohi tarball is prebuilt-only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
VERSION_FILE="$ROOT/overlay/third-party/uboot.version"
CACHE="$ROOT/.cache/rockchip-u-boot"
REPO="${UBOOT_REPO:-https://github.com/rockchip-linux/u-boot.git}"
BRANCH="${UBOOT_BRANCH:-$(tr -d '[:space:]' <"$VERSION_FILE")}"
UBOOT_DIR="$SDK/u-boot"
MARKER="$UBOOT_DIR/.lws-src-installed"
FORCE="${FORCE:-0}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$SDK" ]] || die "SDK missing at $SDK"

if [[ "$FORCE" == "1" ]]; then
  rm -f "$MARKER"
fi

if [[ -f "$UBOOT_DIR/Makefile" && -f "$MARKER" ]]; then
  bash "$ROOT/overlay/device/rockchip/common/scripts/patch-uboot-bootcmd.sh" \
    "$UBOOT_DIR/include/configs/rockchip-common.h" 2>/dev/null || true
  echo "u-boot source ready: $UBOOT_DIR"
  exit 0
fi

if [[ ! -d "$CACHE/.git" ]]; then
  echo "Cloning $REPO (branch $BRANCH) ..."
  rm -rf "$CACHE"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$CACHE"
fi

if [[ -d "$UBOOT_DIR" && ! -f "$UBOOT_DIR/Makefile" ]]; then
  mkdir -p "$SDK/u-boot.prebuilt"
  for f in "$UBOOT_DIR"/*; do
    [[ -e "$f" ]] || continue
    cp -a "$f" "$SDK/u-boot.prebuilt/"
  done
  rm -rf "$UBOOT_DIR"
fi

mkdir -p "$UBOOT_DIR"
echo "Installing u-boot source into $UBOOT_DIR ..."
rsync -a --delete \
  --exclude .git \
  "$CACHE/" "$UBOOT_DIR/"

# SDK lunch uses RK_UBOOT_CFG=rk3566_rk3568; public tree has rk3568_defconfig.
if [[ ! -e "$UBOOT_DIR/configs/rk3566_rk3568_defconfig" ]]; then
  ln -sf rk3568_defconfig "$UBOOT_DIR/configs/rk3566_rk3568_defconfig"
fi

touch "$MARKER"
bash "$ROOT/overlay/device/rockchip/common/scripts/patch-uboot-bootcmd.sh" \
  "$UBOOT_DIR/include/configs/rockchip-common.h" || true

echo "u-boot source installed ($(git -C "$CACHE" rev-parse --short HEAD))"
