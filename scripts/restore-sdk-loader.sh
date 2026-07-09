#!/usr/bin/env bash
# Restore paired SDK MiniLoaderAll.bin (481728 B). Docker volume may have been
# overwritten with MuJia loader (465344 B) by an earlier build-img run.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-}"
if [[ -z "$SDK" ]]; then
  SDK="$(bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true)"
fi
if [[ ! -d "$SDK" && -d /work/sdk ]]; then
  SDK=/work/sdk
fi
FIRMWARE="$SDK/output/firmware"
ANDROID_MD5="5f9a0d36102d5cef31dadd1c21eda251"
SDK_MIN_SIZE=470000

die() {
  echo "ERROR: $*" >&2
  exit 1
}

file_size() {
  wc -c <"$1" | tr -d ' '
}

file_md5() {
  md5 -q "$1" 2>/dev/null || md5sum "$1" | awk '{print $1}'
}

find_host_sdk_loader() {
  local host_sdk
  host_sdk="$(bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true)"
  local candidate
  for candidate in \
    "$host_sdk/u-boot/rk356x_spl_loader_v1.23.114.bin" \
    "$host_sdk/u-boot/"*_loader_*.bin; do
    [[ -r "$candidate" ]] || continue
    [[ "$(file_size "$candidate")" -ge "$SDK_MIN_SIZE" ]] || continue
    [[ "$(file_md5 "$candidate")" == "$ANDROID_MD5" ]] && continue
    echo "$candidate"
    return 0
  done
  return 1
}

find_sdk_loader() {
  local candidate
  for candidate in \
    "$SDK/u-boot/rk356x_spl_loader_v1.23.114.bin" \
    "$SDK/u-boot/"*_loader_*.bin \
    "$ROOT/prebuilt/sdk-loader/MiniLoaderAll.bin"; do
    [[ -r "$candidate" ]] || continue
    [[ "$(file_size "$candidate")" -ge "$SDK_MIN_SIZE" ]] || continue
    [[ "$(file_md5 "$candidate")" == "$ANDROID_MD5" ]] && continue
    echo "$candidate"
    return 0
  done
  find_host_sdk_loader
}

restore_loader() {
  local loader dest size md5

  [[ -d "$SDK" ]] || die "SDK not found: $SDK"
  loader="$(find_sdk_loader)" || die "SDK MiniLoaderAll not found (need 481728 B rk356x_spl_loader)"

  size="$(file_size "$loader")"
  md5="$(file_md5 "$loader")"
  echo "SDK loader source: $loader ($size bytes, md5=$md5)"

  mkdir -p "$SDK/u-boot" "$FIRMWARE"
  dest="$SDK/u-boot/rk356x_spl_loader_v1.23.114.bin"
  if [[ ! -r "$dest" ]] || [[ "$(file_size "$dest")" -lt "$SDK_MIN_SIZE" ]] \
    || [[ "$(file_md5 "$dest")" == "$ANDROID_MD5" ]]; then
    cp -f "$loader" "$dest"
    echo "restored $dest"
  fi

  rm -f "$FIRMWARE/MiniLoaderAll.bin"
  cp -f "$dest" "$FIRMWARE/MiniLoaderAll.bin"
  echo "firmware loader: $FIRMWARE/MiniLoaderAll.bin (${size} bytes)"
}

restore_loader
