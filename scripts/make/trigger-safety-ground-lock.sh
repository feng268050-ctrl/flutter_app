#!/usr/bin/env bash
# Trigger the safety ground lock prompt on a connected device (staging/debug builds only).
set -euo pipefail

PACKAGE="com.lasercyber.lws.ui"
ACTION="com.lasercyber.lws.ui.action.DEMO_SAFETY_GROUND_LOCK"
RECEIVER="${PACKAGE}/com.lasercyber.lws.ui.common.handler.DemoSafetyGroundLockReceiver"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

adb_cmd() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    adb -s "$ADB_SERIAL" "$@"
  else
    adb "$@"
  fi
}

trigger() {
  adb_cmd shell am broadcast \
    -a "$ACTION" \
    -n "$RECEIVER" >/dev/null
  echo "OK: safety ground lock prompt broadcast sent"
  echo "INFO: filter logcat with: adb logcat -s DemoSafetyGroundLock"
}

main() {
  local cmd="${1:-trigger}"
  case "$cmd" in
    trigger)
      trigger
      ;;
    -h|--help|help)
      echo "Usage: $0 trigger"
      ;;
    *)
      die "unknown subcommand: $cmd (expected: trigger)"
      ;;
  esac
}

main "$@"
