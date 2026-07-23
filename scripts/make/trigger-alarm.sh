#!/usr/bin/env bash
# Trigger a demo alarm popup on a connected device (staging/debug builds only).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PACKAGE="com.lasercyber.lws.ui"
ACTION="com.lasercyber.lws.ui.action.DEMO_ALARM"
CLEAN_ACTION="com.lasercyber.lws.ui.action.DEMO_ALARM_CLEAN"
RECEIVER="${PACKAGE}/com.lasercyber.lws.ui.common.handler.DemoAlarmReceiver"

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
  local code="${1:-}"
  if [[ -z "$code" ]]; then
    die "CODE is required (example: make alarm CODE=C002)"
  fi
  adb_cmd shell am broadcast \
    -a "$ACTION" \
    -n "$RECEIVER" \
    --es code "$code" >/dev/null
  echo "OK: demo alarm broadcast sent for code=${code}"
  echo "INFO: filter logcat with: adb logcat -s DemoAlarm"
}

clean() {
  adb_cmd shell am broadcast \
    -a "$CLEAN_ACTION" \
    -n "$RECEIVER" >/dev/null
  echo "OK: alarm restrictions clean broadcast sent (visible popup unchanged)"
  echo "INFO: filter logcat with: adb logcat -s DemoAlarm WarnEpisodeController"
}

usage() {
  echo "Usage: $0 trigger <ALARM_CODE>"
  echo "       $0 clean"
  echo "Example: $0 trigger C002"
  echo "Example: $0 clean"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    trigger)
      shift
      trigger "${1:-}"
      ;;
    clean)
      clean
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      die "unknown subcommand: $cmd (expected: trigger, clean)"
      ;;
  esac
}

main "$@"
