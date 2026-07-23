#!/usr/bin/env bash
# After replacing /system/priv-app/LwsUI/LwsUI.apk, some ROMs never refresh
# PackageManager: getPackageInfo() / dumpsys still show the old versionName while
# the APK on disk is new. Running pm install on the device-local APK updates
# PackageSetting without re-streaming the file over adb.
#
# On RK/AOSP, that pm install often also creates UPDATED_SYSTEM_APP under /data/app/.
# Immediately strip the user-update overlay so pm path stays on priv-app while
# keeping the refreshed versionCode (verified on rk3566).
#
# Usage: sync-pm-after-priv-app-install.sh [<host-apk-for-check-and-fallback>]
# - If <host-apk> is passed: must exist on the build host (make passes TARGET_APK).
# - Install uses /system/priv-app/LwsUI/LwsUI.apk on the device (same path as install-priv-app.sh).
# Env: ADB_SERIAL (optional)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

DEVICE_APK="${LWS_PRIV_APP_APK}"
HOST_APK="${1:-}"

if [[ -n "$HOST_APK" ]]; then
  [[ -f "$HOST_APK" ]] || die "APK not found: $HOST_APK"
fi

echo "INFO: syncing PackageManager metadata (pm install -r -d $DEVICE_APK)..." >&2
adb_bin wait-for-device >/dev/null 2>&1 || true
adb_bin shell test -f "$DEVICE_APK" || die "device file missing: $DEVICE_APK"

pm_out="$(adb_bin shell pm install -r -d "$DEVICE_APK" 2>&1 | tr -d '\r')" || true
printf '%s\n' "$pm_out" >&2
if echo "$pm_out" | grep -q 'Success'; then
  strip_priv_app_user_update_overlay "$LWS_UI_PKG"
  echo "OK: PackageManager metadata synced." >&2
  exit 0
fi

if [[ "${INSTALL_STRICT:-}" == "1" ]]; then
  die "pm install failed under INSTALL_STRICT=1 (streamed adb install fallback disabled): $pm_out"
fi

if [[ -n "$HOST_APK" ]]; then
  echo "WARN: pm install from device path failed; falling back to streamed adb install..." >&2
  adb_bin install -r -d "$HOST_APK"
  strip_priv_app_user_update_overlay "$LWS_UI_PKG"
  echo "OK: PackageManager metadata synced (streamed fallback)." >&2
else
  die "pm install failed (pass host APK as arg to allow streamed fallback): $pm_out"
fi
