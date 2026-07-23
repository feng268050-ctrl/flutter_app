#!/usr/bin/env bash
# Launch DevActivity on a connected adb device (no rebuild, no force-stop).
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"

PKG="${PKG:-com.lasercyber.lws.ui}"
ACTIVITY=".activitys.dev.DevActivity"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"

echo "INFO: launching ${PKG}/${ACTIVITY}..." >&2
adb_bin shell am start -n "${PKG}/${ACTIVITY}" || die "failed to launch DevActivity"
echo "OK: DevActivity launched."
