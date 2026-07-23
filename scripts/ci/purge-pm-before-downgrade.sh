#!/usr/bin/env bash
# Pre-install purge when target versionCode < installed versionCode.
# Usage: purge-pm-before-downgrade.sh <host-apk>
# Env: ADB_SERIAL (optional); sets CLOUD_WAS_DOWNGRADE=1 when downgrade purge runs
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

HOST_APK="${1:-}"
[[ -n "$HOST_APK" && -f "$HOST_APK" ]] || die "usage: $0 <host-apk>"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state"

TARGET_CODE="$("${SCRIPT_DIR}/apk-version-read.sh" "$HOST_APK" versionCode)"
INSTALLED_CODE="$("${SCRIPT_DIR}/installed-apk-version-read.sh" "$LWS_UI_PKG" versionCode)"

if [[ -z "$INSTALLED_CODE" ]]; then
  echo "INFO: package not installed; skip downgrade purge" >&2
  exit 0
fi

if (( TARGET_CODE >= INSTALLED_CODE )); then
  echo "INFO: not a downgrade (target=${TARGET_CODE} installed=${INSTALLED_CODE}); skip purge" >&2
  exit 0
fi

echo "INFO: downgrade detected (target=${TARGET_CODE} installed=${INSTALLED_CODE}); pre-install purge..." >&2
mark_cloud_downgrade

adb_bin shell am force-stop "$LWS_UI_PKG" >/dev/null 2>&1 || true
adb_bin shell pm uninstall-system-updates "$LWS_UI_PKG" >/dev/null 2>&1 || true
adb_bin shell cmd package uninstall-system-updates "$LWS_UI_PKG" >/dev/null 2>&1 || true
adb_bin shell pm clear "$LWS_UI_PKG" >/dev/null 2>&1 || true

"${SCRIPT_DIR}/purge-package-cache-for-pkg.sh" "$LWS_UI_PKG"
"${SCRIPT_DIR}/assert-pm-priv-app-path.sh" "$LWS_UI_PKG"

echo "OK: pre-install downgrade purge complete" >&2
