#!/usr/bin/env bash
# Reboot the configured adb device and wait for reconnect + boot completion.
# Honors ADB_SERIAL. Supports network adb (ip:port) with post-reboot reconnect polling.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"

if [[ -n "${ADB_SERIAL:-}" ]]; then
  echo "INFO: rebooting device ${ADB_SERIAL}..." >&2
else
  echo "INFO: rebooting default adb device..." >&2
fi
adb_bin reboot >/dev/null 2>&1 || die "reboot failed"
wait_boot_after_reboot
