#!/usr/bin/env bash
set -euo pipefail

# Pull ynh960 display param files from a running Android device via adb.
#
# Usage:
#   SN=10.0.0.239:5555 scripts/pull-display-params.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD="$ROOT/board/from-device"
SN="${SN:-${SERIAL:-10.0.0.239:5555}}"
ADB=(adb -s "$SN")

require_device() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "ERROR: adb not found" >&2
    exit 1
  fi
  adb connect "$SN" >/dev/null 2>&1 || true
  "${ADB[@]}" wait-for-device
  "${ADB[@]}" root >/dev/null 2>&1 || true
  sleep 1
  "${ADB[@]}" wait-for-device
}

require_device
mkdir -p "$BOARD"

pull() {
  local remote="$1"
  local local_name="$2"
  "${ADB[@]}" pull "$remote" "$BOARD/$local_name"
}

pull /system/etc/960_lcd_param_rk356x.txt 960_lcd_param_rk356x.system.txt
pull /system/etc/lcd_mipi_param.txt lcd_mipi_param.system.txt

cp -f "$BOARD/960_lcd_param_rk356x.system.txt" "$ROOT/board/960_lcd_param_rk356x.txt"
cp -f "$BOARD/lcd_mipi_param.system.txt" "$ROOT/board/lcd_mipi_param.txt"

echo "Updated:"
echo "  $ROOT/board/960_lcd_param_rk356x.txt"
echo "  $ROOT/board/lcd_mipi_param.txt"
echo "Run: make apply-overlay"
