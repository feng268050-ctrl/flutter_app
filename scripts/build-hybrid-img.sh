#!/usr/bin/env bash
# DEPRECATED: Android uboot + Linux parameter.txt are incompatible (different GPT).
# Use make build-img && make flash for full Linux firmware instead.
set -euo pipefail

echo "ERROR: update-hybrid.img mixes Android uboot with Linux partition table — device will not boot." >&2
echo "Use: make build-img && make flash  (SDK Linux from MaskROM)" >&2
exit 1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_FIRMWARE="$ROOT/output/firmware"
ANDROID_BOOT="$OUT_FIRMWARE/android-boot"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

install_hybrid_img() {
  local src="$1"
  local dest="$OUT_FIRMWARE/update-hybrid.img"
  cp -f "$src" "$dest"
  ls -lh "$dest"
  echo "update-hybrid.img ready: $dest"
}

pack_hybrid_in_sdk() {
  local sdk="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
  local firmware="$sdk/output/firmware"
  local updateimg="$firmware/update.img"

  [[ -d "$sdk" ]] || die "SDK not found — run: make link-sdk"
  [[ -r "$sdk/output/.config" ]] || die "output/.config missing — run make lunch first"
  [[ -r "$ANDROID_BOOT/MiniLoaderAll.bin" && -r "$ANDROID_BOOT/uboot.img" ]] || \
    die "Android boot chain missing — run: bash scripts/extract-android-boot.sh"

  for img in boot.img rootfs.img misc.img parameter.txt; do
    [[ -r "$firmware/$img" ]] || die "$img missing in $firmware — run make build-rootfs && make build-kernel"
  done

  cp -f "$ANDROID_BOOT/MiniLoaderAll.bin" "$firmware/MiniLoaderAll.bin"
  cp -f "$ANDROID_BOOT/uboot.img" "$firmware/uboot.img"
  echo "Using Android MiniLoaderAll.bin + uboot.img (ynh960 MIPI boot logo path)"

  echo "Packing hybrid update.img ..."
  cd "$sdk"
  ./build.sh updateimg

  [[ -r "$updateimg" ]] || die "pack failed: $updateimg"
  install_hybrid_img "$updateimg"
}

if [[ "${LWS_HMI_PACK_HYBRID:-}" == "1" ]]; then
  pack_hybrid_in_sdk
  exit 0
fi

bash "$ROOT/scripts/extract-android-boot.sh"
export LWS_HMI_PACK_HYBRID=1
bash "$ROOT/scripts/docker-run.sh" \
  bash -c 'export LWS_HMI_PACK_HYBRID=1; bash /work/lws-hmi/scripts/build-hybrid-img.sh'
