#!/usr/bin/env bash
# Post PM-sync purge when a downgrade install was performed.
# Does NOT pm clear after install (that drops priv-app PM registration on some ROMs).
# Usage: purge-pm-after-downgrade.sh <host-apk>
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

HOST_APK="${1:-}"
[[ -n "$HOST_APK" && -f "$HOST_APK" ]] || die "usage: $0 <host-apk>"

if ! cloud_was_downgrade; then
  TARGET_CODE="$("${SCRIPT_DIR}/apk-version-read.sh" "$HOST_APK" versionCode)"
  INSTALLED_CODE="$("${SCRIPT_DIR}/installed-apk-version-read.sh" "$LWS_UI_PKG" versionCode)"
  if [[ -n "$INSTALLED_CODE" ]] && (( TARGET_CODE < INSTALLED_CODE )); then
    mark_cloud_downgrade
  else
    echo "INFO: not a downgrade; skip post-install purge" >&2
    exit 0
  fi
fi

echo "INFO: post-install downgrade purge (package_cache only, no pm clear)..." >&2

ensure_adb_ready_stable || die "adb not ready for post-install purge"

adb_bin shell pm uninstall-system-updates "$LWS_UI_PKG" >/dev/null 2>&1 || true
adb_bin shell cmd package uninstall-system-updates "$LWS_UI_PKG" >/dev/null 2>&1 || true
"${SCRIPT_DIR}/purge-package-cache-for-pkg.sh" "$LWS_UI_PKG"

# Refresh PM if package_cache purge or prior steps left pm path empty / overlay.
paths="$(adb_bin shell pm path "$LWS_UI_PKG" 2>/dev/null | tr -d '\r' || true)"
if echo "$paths" | grep -q '/data/app/'; then
  echo "INFO: pm path still has /data/app overlay; strip user update (not bare resync)..." >&2
  strip_priv_app_user_update_overlay "$LWS_UI_PKG"
  paths="$(adb_bin shell pm path "$LWS_UI_PKG" 2>/dev/null | tr -d '\r' || true)"
fi
if [[ -z "$paths" ]]; then
  echo "INFO: pm path empty; resync from priv-app APK..." >&2
  "${SCRIPT_DIR}/resync-pm-from-priv-app-apk.sh"
fi

"${SCRIPT_DIR}/assert-pm-priv-app-path.sh" "$LWS_UI_PKG"

echo "OK: post-install downgrade purge complete" >&2
clear_cloud_downgrade_mark
