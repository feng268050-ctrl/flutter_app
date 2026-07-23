#!/usr/bin/env bash
# Stop and relaunch the LWS UI app on a connected adb device.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"

PKG="${PKG:-com.lasercyber.lws.ui}"
ACTIVITY="${ACTIVITY:-.activitys.SplashActivity}"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"

echo "INFO: stopping ${PKG}..." >&2
adb_bin shell am force-stop "$PKG" >/dev/null 2>&1 || true
echo "INFO: launching ${PKG}..." >&2
adb_bin shell am start -W -n "${PKG}/${ACTIVITY}" >/dev/null 2>&1 \
  || adb_bin shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
  || die "failed to relaunch app (am start / monkey)"
echo "OK: app relaunched."
