#!/usr/bin/env bash
# Best-effort PackageManager package_cache cleanup for one package.
# Usage: purge-package-cache-for-pkg.sh [package]
# Env: ADB_SERIAL (optional)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

PKG="${1:-$LWS_UI_PKG}"

echo "INFO: purging package_cache for ${PKG}..." >&2

ensure_adb_root || echo "WARN: adb root unavailable; skipping package_cache file purge" >&2

if adb_has_root; then
  adb_bin shell su 0 sh -c "
    rm -rf /data/system/package_cache/*/${PKG}* 2>/dev/null || true
    rm -rf /data/system/package_cache/${PKG}* 2>/dev/null || true
    find /data/system/package_cache -maxdepth 3 -type d -name '${PKG}' -exec rm -rf {} + 2>/dev/null || true
  " 2>/dev/null || true
fi

adb_bin shell cmd package compile -f -m speed "$PKG" 2>/dev/null || true
wait_adb_stable >/dev/null 2>&1 || true

echo "OK: package_cache purge attempted for ${PKG}" >&2
