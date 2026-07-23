#!/usr/bin/env bash
# Read versionCode, versionName, package from an APK via aapt dump badging.
# Usage: apk-version-read.sh <apk> [versionCode|versionName|package]
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

APK="${1:-}"
FIELD="${2:-}"

[[ -n "$APK" ]] || die "usage: $0 <apk> [versionCode|versionName|package]"
[[ -f "$APK" ]] || die "APK not found: $APK"

AAPT="$(resolve_aapt)" || die "aapt not found (install Android SDK build-tools or add aapt to PATH)"

badging="$("$AAPT" dump badging "$APK" 2>/dev/null)" || die "aapt dump badging failed: $APK"

read_field() {
  case "$1" in
    versionCode)
      sed -n "s/^package: name='[^']*' versionCode='\([^']*\)'.*/\1/p" <<<"$badging" | head -n 1
      ;;
    versionName)
      sed -n "s/^package: name='[^']*' versionCode='[^']*' versionName='\([^']*\)'.*/\1/p" <<<"$badging" | head -n 1
      ;;
    package)
      sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging" | head -n 1
      ;;
    *)
      die "unknown field: $1 (use versionCode, versionName, or package)"
      ;;
  esac
}

if [[ -n "$FIELD" ]]; then
  val="$(read_field "$FIELD")"
  [[ -n "$val" ]] || die "failed to read $FIELD from $APK"
  printf '%s\n' "$val"
  exit 0
fi

printf 'versionCode=%s\n' "$(read_field versionCode)"
printf 'versionName=%s\n' "$(read_field versionName)"
printf 'package=%s\n' "$(read_field package)"
