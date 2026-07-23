#!/usr/bin/env bash
# Read installed versionCode / versionName for a package via dumpsys package.
# Usage: installed-apk-version-read.sh [package] [versionCode|versionName]
# Env: ADB_SERIAL (optional)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

PKG="${1:-$LWS_UI_PKG}"
FIELD="${2:-}"

dump="$(adb_bin shell dumpsys package "$PKG" 2>/dev/null | tr -d '\r')" || true

read_installed_field() {
  case "$1" in
    versionCode)
      printf '%s\n' "$dump" | sed -n 's/.*versionCode=\([0-9][0-9]*\).*/\1/p' | head -n 1
      ;;
    versionName)
      printf '%s\n' "$dump" | sed -n 's/.*versionName=\([^ ]*\).*/\1/p' | head -n 1
      ;;
    *)
      die "unknown field: $1"
      ;;
  esac
}

is_installed() {
  adb_bin shell pm path "$PKG" 2>/dev/null | tr -d '\r' | grep -q .
}

if ! is_installed; then
  if [[ -n "$FIELD" ]]; then
    printf '\n'
    exit 0
  fi
  printf 'installed=0\n'
  exit 0
fi

if [[ -n "$FIELD" ]]; then
  val="$(read_installed_field "$FIELD")"
  printf '%s\n' "${val:-}"
  exit 0
fi

printf 'installed=1\n'
printf 'versionCode=%s\n' "$(read_installed_field versionCode)"
printf 'versionName=%s\n' "$(read_installed_field versionName)"
