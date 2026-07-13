#!/usr/bin/env bash
# Pre-flight check before flashing SDK Linux from MaskROM.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
UPGRADE="$ROOT/tools/upgrade_tool/upgrade_tool"
FW_LWS="$ROOT/output/firmware"
FW_SDK="$SDK/output/firmware"
SDK_LOADER=481728
LINUX_BOOT_MAX=$((64 * 1024 * 1024))

warn() { echo "WARN: $*"; }
ok() { echo "OK:  $*"; }
bad() { echo "FAIL: $*"; FAIL=1; }

FAIL=0

section() { echo ""; echo "=== $* ==="; }

file_size() {
  [[ -r "$1" ]] && wc -c <"$1" | tr -d ' ' || echo 0
}

section "SDK lunch (.config)"
if [[ -r "$SDK/output/.config" ]]; then
  grep -E '^RK_(PARAMETER|BOOT_FIT_ITS|KERNEL_DTS|BUILDROOT_BASE|USE_FIT)' "$SDK/output/.config" \
    | sed 's/^/  /' || true
  grep -qE '^RK_USE_FIT_IMG=(y|"y")$' "$SDK/output/.config" \
    || bad "RK_USE_FIT_IMG not enabled — boot.img won't be FIT (boot_fit cannot load kernel)"
  param="$(grep '^RK_PARAMETER=' "$SDK/output/.config" | cut -d= -f2- | tr -d '"')"
  [[ "$param" == "parameter-buildroot-fit.txt" ]] \
    || bad "RK_PARAMETER=$param (expected parameter-buildroot-fit.txt — SDK Linux GPT)"
else
  bad "no output/.config — run: make lunch"
fi

section "boot.img (SDK ynh960 kernel — make build-kernel)"
boot_size="$(file_size "$FW_SDK/boot.img")"
if [[ "$boot_size" -gt "$LINUX_BOOT_MAX" ]]; then
  bad "boot.img = $((boot_size / 1024 / 1024)) MiB (>64 MiB Linux boot partition)"
elif [[ "$boot_size" -gt 0 ]]; then
  ok "boot.img = $((boot_size / 1024 / 1024)) MiB"
  if [[ -r "$FW_SDK/boot.img" ]] && ! xxd "$FW_SDK/boot.img" 2>/dev/null | head -1 | grep -q 'd00d feed'; then
    if ! xxd -s 0x800 -l 4 "$FW_SDK/boot.img" 2>/dev/null | grep -q 'd00d feed'; then
      bad "boot.img has no FIT header — run: make build-kernel (need RK_USE_FIT_IMG=y)"
    else
      ok "boot.img FIT header at 0x800 (Rockchip FIT boot)"
    fi
  else
    ok "boot.img FIT header at 0x0"
  fi
else
  bad "boot.img missing — run: make build-kernel"
fi

section "update.img (make build-img → make flash from MaskROM)"
p="$FW_LWS/update.img"
if [[ -r "$p" ]]; then
  echo "  $(file_size "$p") bytes"
  if [[ -x "$UPGRADE" ]]; then
    "$UPGRADE" SFI "$p" 2>&1 | grep -v '^Using ' \
      | grep -E 'Loader Time|Build Time|FIRMWARE_VER|partition=' | sed 's/^/  /' || true
  fi
  loader_size="$(file_size "$FW_SDK/MiniLoaderAll.bin")"
  if strings "$FW_SDK/output/firmware/uboot.img" 2>/dev/null | grep -q 'boot_android.*boot_fit'; then
    warn "uboot: vendor boot_android→boot_fit (expected; Linux needs Innohi uboot or TTL boot_fit)"
  elif strings "$FW_SDK/output/firmware/uboot.img" 2>/dev/null | grep -q '^bootcmd=boot_fit;bootrkp'; then
    warn "uboot: patched/compiled boot_fit — do not flash (ynh960 brick risk)"
  elif [[ -r "$FW_SDK/output/firmware/uboot.img" ]]; then
    warn "uboot bootcmd unrecognized"
  fi
  if [[ "$loader_size" -eq "$SDK_LOADER" ]]; then
    ok "SDK loader (${loader_size}B)"
  elif [[ "$loader_size" -gt 0 ]]; then
    warn "loader ${loader_size}B (expected SDK ${SDK_LOADER}B)"
  fi
else
  bad "update.img missing — run: make build-img"
fi

section "USB"
if [[ "$(uname -s)" == Darwin && -x "$UPGRADE" ]]; then
  bash "$ROOT/scripts/flash-usb.sh" devices 2>/dev/null || true
fi

section "Flash from MaskROM (no Android step)"
cat <<'EOF'
  boot.img  = SDK ynh960 kernel (make build-kernel), NOT Android boot.img
  GPT       = parameter-buildroot-fit.txt (SDK Linux)

  MaskROM → Linux:
    make build-kernel && make build-rootfs && make build-img
    make audit
    make flash              # ul if Maskrom, uf if Loader

  make flash-android        = optional MuJia Android image (you don't need this for Linux)
EOF

section "Result"
if [[ "$FAIL" -eq 0 ]]; then
  echo "Ready to flash Linux from MaskROM."
else
  echo "Fix issues above before make flash."
  exit 1
fi
