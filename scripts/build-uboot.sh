#!/usr/bin/env bash
# Build U-Boot from source with Linux-first bootcmd (ynh960 / Buildroot GPT).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${LWS_HMI_BUILD_UBOOT:-}" == "1" ]]; then
  SDK="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
  [[ -d "$SDK" ]] || { echo "ERROR: SDK missing" >&2; exit 1; }

  bash "$ROOT/scripts/apply-overlay.sh" >/dev/null
  bash "$ROOT/scripts/fetch-uboot.sh"
  bash "$ROOT/scripts/sync-lunch-config.sh"

  cd "$SDK"
  ./build.sh uboot

  uboot="$SDK/u-boot/uboot.img"
  loader="$(echo "$SDK/u-boot"/*_loader_*.bin | head -1)"
  [[ -r "$uboot" ]] || { echo "ERROR: build produced no uboot.img" >&2; exit 1; }

  mkdir -p "$ROOT/output/firmware"
  cp -f "$uboot" "$ROOT/output/firmware/uboot.img"
  echo "WARNING: compiled loader is NOT copied — use prebuilt/sdk-loader/MiniLoaderAll.bin in update.img" >&2

  echo "uboot.img: $(wc -c <"$uboot" | tr -d ' ') bytes (compiled — experimental)"
  strings "$uboot" | grep '^bootcmd=' || true
  exit 0
fi

export LWS_HMI_BUILD_UBOOT=1
bash "$ROOT/scripts/docker-run.sh" \
  bash -c 'export LWS_HMI_BUILD_UBOOT=1; bash /work/lws-hmi/scripts/build-uboot.sh'
