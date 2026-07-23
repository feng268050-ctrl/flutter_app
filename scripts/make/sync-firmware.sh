#!/usr/bin/env bash
# Push latest repo firmware/*.bin to device and trigger Modbus OTA (no confirm, no version gate).
# Requires the app to already be running in the foreground (does not launch it).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE="com.lasercyber.lws.ui"
ACTION="com.lasercyber.lws.ui.action.SYNC_FIRMWARE"
RECEIVER="${PACKAGE}/com.lasercyber.lws.ui.common.handler.SyncFirmwareReceiver"
DEVICE_DIR="/sdcard/Download/lws-sync-firmware"
PICK_SCRIPT="${ROOT}/scripts/make/pick-latest-firmware-bin.sh"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"

app_in_foreground() {
  local top focus
  top="$(adb_bin shell dumpsys activity activities 2>/dev/null | tr -d '\r' \
    | grep -E 'topResumedActivity=|mResumedActivity:' | head -n1 || true)"
  if [[ -n "$top" && "$top" == *"${PACKAGE}"* ]]; then
    return 0
  fi
  focus="$(adb_bin shell dumpsys window 2>/dev/null | tr -d '\r' \
    | grep -E 'mCurrentFocus=|mFocusedApp=' | head -n1 || true)"
  if [[ -n "$focus" && "$focus" == *"${PACKAGE}"* ]]; then
    return 0
  fi
  return 1
}

require_app_foreground() {
  if app_in_foreground; then
    echo "INFO: ${PACKAGE} is in foreground"
    return 0
  fi
  die "${PACKAGE} is not in the foreground — open the app on the device and retry"
}

main() {
  if [[ ! -x "$PICK_SCRIPT" ]]; then
    chmod +x "$PICK_SCRIPT"
  fi
  local firmware_bin
  firmware_bin="$("$PICK_SCRIPT" 2>/dev/null || true)"
  if [[ -z "$firmware_bin" ]]; then
    die "no firmware bin under firmware/ (expected LSW01H####S####.bin)"
  fi
  if [[ ! -f "$firmware_bin" ]]; then
    die "firmware file not found: $firmware_bin"
  fi

  local name
  name="$(basename "$firmware_bin")"
  local device_path="${DEVICE_DIR}/${name}"

  echo "INFO: selected firmware ${firmware_bin}"
  require_app_foreground

  adb_bin shell mkdir -p "$DEVICE_DIR"
  adb_bin push "$firmware_bin" "$device_path"
  echo "INFO: pushed to ${device_path}"

  adb_bin shell am broadcast \
    -a "$ACTION" \
    -n "$RECEIVER" \
    --es firmware_path "$device_path" >/dev/null
  echo "OK: sync-firmware broadcast sent (upgrade progress dialog on device; no version check)"
  echo "INFO: logcat filter: adb logcat -s SyncFirmwareTrigger BundledFirmwareBootstrap ControllerUpgradeHandler"
}

main "$@"
