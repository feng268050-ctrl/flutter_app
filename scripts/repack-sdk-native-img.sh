#!/usr/bin/env bash
# Rebuild SDK-native kernel (boot.its FIT) + updateimg when rootfs already exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
OUT="$ROOT/output/firmware"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
DEFCONFIG="${SDK_NATIVE_DEFCONFIG:-ynh960_innohi_defconfig}"
CHIP="${SDK_NATIVE_CHIP:-rk3566_rk3568}"
LINUX_BOOT_MAX=$((64 * 1024 * 1024))

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$SDK" ]] || die "SDK missing"

bash "$ROOT/scripts/prepare-sdk-native.sh"

cd "$SDK"

if [[ ! -r output/.config ]]; then
  ./build.sh "${CHIP}:${DEFCONFIG}"
else
  grep -q 'RK_BOOT_FIT_ITS_NAME="boot.its"' output/.config \
    || die "output/.config not sdk-native — run: make build-sdk-native first"
fi

./build.sh loader
./build.sh kernel
./build.sh updateimg

boot="$SDK/kernel-6.1/boot.img"
[[ -r "$boot" ]] || boot="$SDK/kernel/arch/arm64/boot.img"
[[ -r "$boot" ]] || die "boot.img missing after kernel build"

boot_bytes="$(wc -c <"$boot" | tr -d ' ')"
echo "boot.img:"
bash "$SIZE_HELPER" "$boot"
[[ "$boot_bytes" -le "$LINUX_BOOT_MAX" ]] || die "boot.img exceeds 64 MiB Linux boot partition"

mkdir -p "$OUT"
cp -fL "$SDK/output/update/Image/update.img" "$OUT/update.img" 2>/dev/null \
  || cp -f "$SDK/output/firmware/update.img" "$OUT/update.img"
cp -f "$SDK/output/firmware/MiniLoaderAll.bin" "$OUT/MiniLoaderAll.bin" 2>/dev/null || true

bash "$ROOT/scripts/audit-sdk-native.sh" "$boot" "$OUT/update.img"

echo ""
echo "=== repack done ==="
bash "$SIZE_HELPER" "$OUT/update.img"
echo "Flash: make flash"
