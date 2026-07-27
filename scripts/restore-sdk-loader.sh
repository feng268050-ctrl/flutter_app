#!/usr/bin/env bash
# Restore paired SDK MiniLoaderAll.bin (481728 B). Docker volume may have been
# overwritten with Innohi loader (465344 B) by an earlier build-img run.
# Authoritative copy: prebuilt/sdk-loader (or prebuilt/bootloader/<id>/); sdk/u-boot is staging only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
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

acceptable_loader() {
  local candidate="$1"
  [[ -r "$candidate" ]] || return 1
  [[ "$(file_size "$candidate")" -ge "$SDK_MIN_SIZE" ]] || return 1
  [[ "$(file_md5 "$candidate")" == "$ANDROID_MD5" ]] && return 1
  return 0
}

find_sdk_loader() {
  local candidate
  # Prefer repo prebuilt (authoritative); sdk/u-boot is pack staging only.
  for candidate in \
    "$ROOT/prebuilt/sdk-loader/MiniLoaderAll.bin" \
    "$ROOT"/prebuilt/bootloader/*/MiniLoaderAll.bin \
    "$SDK/u-boot/rk356x_spl_loader_v1.23.114.bin" \
    "$SDK/u-boot/"*_loader_*.bin \
    "$ROOT/linux-sdk/u-boot/rk356x_spl_loader_v1.23.114.bin" \
    "$ROOT/linux-sdk/u-boot/"*_loader_*.bin; do
    if acceptable_loader "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

restore_loader() {
  local loader dest size md5

  [[ -d "$SDK" ]] || die "SDK not found: $SDK"
  loader="$(find_sdk_loader)" || die "SDK MiniLoaderAll not found (need 481728 B under prebuilt/sdk-loader)"

  size="$(file_size "$loader")"
  md5="$(file_md5 "$loader")"
  echo "SDK loader source: $loader ($size bytes, md5=$md5)"

  mkdir -p "$SDK/u-boot" "$FIRMWARE"
  dest="$SDK/u-boot/rk356x_spl_loader_v1.23.114.bin"
  if [[ ! -r "$dest" ]] || [[ "$(file_size "$dest")" -lt "$SDK_MIN_SIZE" ]] \
    || [[ "$(file_md5 "$dest")" == "$ANDROID_MD5" ]]; then
    cp -f "$loader" "$dest"
    echo "restored staging $dest"
  fi

  rm -f "$FIRMWARE/MiniLoaderAll.bin"
  cp -f "$dest" "$FIRMWARE/MiniLoaderAll.bin"
  echo "firmware loader: $FIRMWARE/MiniLoaderAll.bin (${size} bytes)"
}

restore_loader
