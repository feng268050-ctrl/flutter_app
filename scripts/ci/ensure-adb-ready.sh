#!/usr/bin/env bash
# Ensure adb target is connected; auto-runs adb connect when ADB_SERIAL is a network address.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"
