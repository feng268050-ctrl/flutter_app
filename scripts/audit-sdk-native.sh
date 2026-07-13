#!/usr/bin/env bash
# Verify Innohi SDK-native image: boot.its FIT (with resource), SDK loader/uboot.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
BOOT="${1:-$SDK/kernel-6.1/boot.img}"
UPDATE="${2:-$ROOT/output/firmware/update.img}"
SDK_LOADER=481728
LINUX_BOOT_MAX=$((64 * 1024 * 1024))
FAIL=0

warn() { echo "WARN: $*"; }
ok() { echo "OK:  $*"; }
bad() { echo "FAIL: $*"; FAIL=1; }

[[ -r "$BOOT" ]] || bad "boot.img missing: $BOOT"
[[ -r "$UPDATE" ]] || bad "update.img missing: $UPDATE"

if [[ -r "$BOOT" ]]; then
  bytes="$(wc -c <"$BOOT" | tr -d ' ')"
  if [[ "$bytes" -gt "$LINUX_BOOT_MAX" ]]; then
    bad "boot.img ${bytes} bytes (>64 MiB)"
  else
    ok "boot.img $((bytes / 1024 / 1024)) MiB"
  fi
  if xxd -s 0x800 -l 4 "$BOOT" 2>/dev/null | grep -qi 'd00d feed'; then
    ok "FIT header at 0x800 (Rockchip boot.img)"
  elif xxd -l 4 "$BOOT" 2>/dev/null | grep -qi 'd00d feed'; then
    ok "FIT header at 0x0"
  else
    bad "no FIT magic in boot.img — need RK_USE_FIT_IMG=y + boot.its"
  fi
  if strings "$BOOT" | grep -qE 'resource|multi'; then
    ok "FIT includes resource/multi (SDK boot.its — Innohi default)"
  elif [[ "$bytes" -gt $((38 * 1024 * 1024)) ]]; then
    ok "boot.img >38 MiB (likely boot.its with resource.img)"
  else
    bad "boot.img looks like boot-slim.its (~38 MiB) — Innohi requires SDK boot.its"
  fi
fi

if [[ -r "$SDK/output/.config" ]]; then
  grep -q 'RK_BOOT_FIT_ITS_NAME="boot.its"' "$SDK/output/.config" \
    && ok "RK_BOOT_FIT_ITS_NAME=boot.its" \
    || warn "lunch config not boot.its ($(grep RK_BOOT_FIT_ITS_NAME "$SDK/output/.config" || echo missing))"
fi

loader="$SDK/output/firmware/MiniLoaderAll.bin"
if [[ -r "$loader" ]]; then
  sz="$(wc -c <"$loader" | tr -d ' ')"
  [[ "$sz" -eq "$SDK_LOADER" ]] && ok "MiniLoaderAll.bin ${sz}B (SDK prebuilt)" \
    || warn "loader ${sz}B (expected ${SDK_LOADER}B)"
fi

uboot="$SDK/output/firmware/uboot.img"
if [[ -r "$uboot" ]]; then
  if strings "$uboot" | grep -q '^bootcmd=boot_android.*boot_fit'; then
    ok "vendor uboot bootcmd (prebuilt, do not compile/patch)"
  else
    warn "unexpected uboot bootcmd"
  fi
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "Innohi SDK-native image checks passed."
else
  echo "Fix failures before flashing good board."
  exit 1
fi
