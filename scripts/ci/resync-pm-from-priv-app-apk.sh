#!/usr/bin/env bash
# Re-register PackageManager metadata from the on-disk priv-app APK.
# Usage: resync-pm-from-priv-app-apk.sh
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

ensure_adb_ready_stable || die "adb not ready for PM resync"

adb_bin shell test -s "${LWS_PRIV_APP_APK}" \
  || die "device APK missing: ${LWS_PRIV_APP_APK}"

echo "INFO: re-sync PM from ${LWS_PRIV_APP_APK}..." >&2
pm_out="$(adb_bin shell pm install -r -d "${LWS_PRIV_APP_APK}" 2>&1 | tr -d '\r')" || true
printf '%s\n' "$pm_out" >&2
echo "$pm_out" | grep -q 'Success' || die "pm install resync failed: $pm_out"

# pm install of priv-app path creates /data/app overlay on many ROMs — strip it.
strip_priv_app_user_update_overlay "$LWS_UI_PKG"

wait_adb_stable >/dev/null 2>&1 || true
echo "OK: PM resynced from priv-app APK" >&2
