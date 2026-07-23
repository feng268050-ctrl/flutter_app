#!/usr/bin/env bash
# Fast app update for make sync: push APK to device, then pm install locally.
# Avoids adb install streaming, which often fails for large APKs over adb connect (remote).
#
# Usage: sync-install.sh <host-apk>
# Env: ADB_SERIAL (optional)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

HOST_APK="${1:-}"
[[ -n "$HOST_APK" ]] || die "usage: $0 <host-apk>"
[[ -f "$HOST_APK" ]] || die "APK not found: $HOST_APK"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"

DEVICE_APK=/data/local/tmp/LwsUI-sync.apk

echo "INFO: pushing $(basename "$HOST_APK") to $DEVICE_APK..."
adb_bin push "$HOST_APK" "$DEVICE_APK"

echo "INFO: installing via pm install -r -d $DEVICE_APK..."
pm_out="$(adb_bin shell pm install -r -d "$DEVICE_APK" 2>&1 | tr -d '\r')" || true
printf '%s\n' "$pm_out"
echo "$pm_out" | grep -q 'Success' || die "pm install failed: $pm_out"

adb_bin shell rm -f "$DEVICE_APK" >/dev/null 2>&1 || true
echo "OK: app installed."
