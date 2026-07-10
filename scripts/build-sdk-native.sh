#!/usr/bin/env bash
# Build Innohi SDK-native Linux for ynh960 (MaskROM flash via make flash).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
OUT="$ROOT/output/firmware"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
DEFCONFIG="${SDK_NATIVE_DEFCONFIG:-ynh960_innohi_defconfig}"
CHIP="${SDK_NATIVE_CHIP:-rk3566_rk3568}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$SDK" ]] || die "SDK missing — run: make link-sdk"

bash "$ROOT/scripts/prepare-sdk-native.sh"

cd "$SDK"

# Docker entrypoint sets MAKEFLAGS=-jN; nested package makes (cmake/gmake) hit jobserver errors.
export LWS_HMI_NO_MAKEFLAGS=1
unset MAKEFLAGS
export BUILD_JOBS="${BUILD_JOBS:-1}"

echo "=== lunch ${CHIP}:${DEFCONFIG} ==="
./build.sh "${CHIP}:${DEFCONFIG}"

echo "=== loader (prebuilt MiniLoaderAll + uboot.img) ==="
./build.sh loader

echo "=== kernel ==="
./build.sh kernel

echo "=== rootfs (Innohi MainServer + second mk-buildroot pass) ==="
./build.sh rootfs

echo "=== updateimg (SDK-native, no lws-hmi build-img overrides) ==="
./build.sh updateimg

[[ -r "$SDK/output/firmware/update.img" ]] || die "update.img not produced"

mkdir -p "$OUT"
cp -f "$SDK/output/firmware/update.img" "$OUT/update.img"
cp -f "$SDK/output/firmware/MiniLoaderAll.bin" "$OUT/MiniLoaderAll.bin" 2>/dev/null || true
cp -f "$SDK/output/firmware/uboot.img" "$OUT/uboot.img" 2>/dev/null || true

echo ""
echo "=== SDK native build done ==="
bash "$SIZE_HELPER" "$OUT/update.img" "$SDK/output/firmware/update.img"
echo ""
echo "MaskROM flash:"
echo "  make flash"
echo "  # or: make flash IMAGE=$OUT/update.img"
echo ""
strings "$SDK/output/firmware/uboot.img" 2>/dev/null | grep '^bootcmd=' || true
