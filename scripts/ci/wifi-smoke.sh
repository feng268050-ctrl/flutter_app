#!/usr/bin/env bash
# wifi-smoke.sh — on-device CI smoke for system-privileged WiFi (WifiManager, NETWORK_SETTINGS).
#
# This HMI pipeline runs against a real device over adb (not headless emulator-only CI).
# By default the script starts the WiFi UI (WifiActivity) so logcat/UI-path checks run.
# Use --skip-launch only when the runner cannot start activities (e.g. debugging static checks).
#
# Recommended CI (device attached, UI available). When multiple adb devices exist, you MUST
# pick the HMI device via one of:
#   --serial <id> | -s <id> | --serial=<id>
#   ADB_SERIAL=<id>   (same effect as --serial; used by this script for adb -s)
#
# Examples:
#   ./scripts/ci/wifi-smoke.sh --serial 3d9204d2c3b32cd9
#   ADB_SERIAL=3d9204d2c3b32cd9 ./scripts/ci/wifi-smoke.sh --with-network-test
#
# Usage:
#   ./scripts/ci/wifi-smoke.sh
#   ./scripts/ci/wifi-smoke.sh --serial <adb-serial>
#   ./scripts/ci/wifi-smoke.sh --skip-launch
#   ./scripts/ci/wifi-smoke.sh --with-network-test
#
# Test AP (override via env):
#   WIFI_TEST_SSID   default: LaserCyber-Global
#   WIFI_TEST_PASS   default: L@serCyber
#
# With --with-network-test:
#   If already associated → disconnect test, then connect test;
#   if not associated → connect test, then disconnect test.
#   "Disconnect" uses cmd wifi disconnect when present; otherwise list-networks + forget-network
#   (removes saved entry for that network; connect-network adds it back).
#
# Exit codes: 0 OK, 1 assertion/prereq failed
#
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

PACKAGE="com.lasercyber.lws.ui"
WIFI_ACTIVITY="${PACKAGE}/.activitys.other.WifiActivity"
SKIP_LAUNCH=0
WITH_NETWORK_TEST=0
# Set by cmd_wifi_require_subcommands: "disconnect" | "forget"
WIFI_DISCONNECT_MODE=""

WIFI_TEST_SSID="${WIFI_TEST_SSID:-LaserCyber-Global}"
WIFI_TEST_PASS="${WIFI_TEST_PASS:-L@serCyber}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-launch)
      SKIP_LAUNCH=1
      shift
      ;;
    --with-network-test)
      WITH_NETWORK_TEST=1
      shift
      ;;
    --serial=*)
      export ADB_SERIAL="${1#--serial=}"
      shift
      ;;
    --serial|-s)
      [[ -n "${2:-}" ]] || die "option $1 requires a device serial (adb devices)"
      export ADB_SERIAL="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,55p' "$0"
      exit 0
      ;;
    *)
      die "unknown option: $1 (try --help)"
      ;;
  esac
done

adb_bin() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    command adb -s "${ADB_SERIAL}" "$@"
  else
    command adb "$@"
  fi
}

need_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
}

device_ready() {
  local out
  out="$(adb_bin devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  [[ -n "$out" ]] || return 1
  if [[ -z "${ADB_SERIAL:-}" ]]; then
    local n
    n="$(echo "$out" | wc -l | tr -d ' ')"
    [[ "$n" -eq 1 ]] || die "Multiple devices/emulators; set ADB_SERIAL or use --serial/-s <id>. Found: $(echo "$out" | tr '\n' ' ')"
  else
    echo "$out" | grep -qx "${ADB_SERIAL}" || die "Device ${ADB_SERIAL} not in 'device' state"
  fi
  return 0
}

wifi_dumpsys() {
  adb_bin shell dumpsys wifi 2>/dev/null || true
}

is_wifi_connected() {
  local d
  d="$(wifi_dumpsys)"
  echo "${d}" | grep -qE 'NetworkInfo\{[^}]*type: WIFI[^}]*state: CONNECTED|type=WIFI[, ].*CONNECTED' && return 0
  echo "${d}" | grep -qE 'Supplicant state: COMPLETED' && return 0
  echo "${d}" | grep -qE 'mWifiInfo.*SSID: "[^"]+"' && return 0
  return 1
}

verify_connected_to_test_ssid() {
  local d
  sleep 4
  d="$(wifi_dumpsys)"
  echo "${d}" | grep -Fq "\"${WIFI_TEST_SSID}\"" \
    || die "Expected SSID \"${WIFI_TEST_SSID}\" not found in dumpsys wifi after connect"
  echo "    OK: associated to ${WIFI_TEST_SSID}"
}

verify_wifi_disconnected() {
  sleep 3
  if is_wifi_connected; then
    die "WiFi still reports associated after disconnect/forget (see dumpsys wifi)"
  fi
  echo "    OK: WiFi no longer associated after disconnect/forget"
}

ensure_cmd_wifi_root() {
  echo "    requesting adbd root for cmd wifi …"
  adb_bin root 2>/dev/null || true
  sleep 1
  adb_bin wait-for-device
}

cmd_wifi_require_subcommands() {
  local help
  help="$(adb_bin shell cmd wifi help 2>/dev/null || true)"
  echo "${help}" | grep -q connect-network || die "cmd wifi connect-network not available on this build"
  # AOSP varies: some builds expose "disconnect", others only list-networks + forget-network.
  if echo "${help}" | grep -qE '^[[:space:]]+disconnect([[:space:]]|$)'; then
    WIFI_DISCONNECT_MODE=disconnect
  elif echo "${help}" | grep -qi 'list-networks' && echo "${help}" | grep -qi 'forget-network'; then
    WIFI_DISCONNECT_MODE=forget
  else
    die "cmd wifi: need either 'disconnect' or both 'list-networks' and 'forget-network'"
  fi
}

run_cmd_wifi_connect() {
  adb_bin shell cmd wifi connect-network "${WIFI_TEST_SSID}" wpa2 "${WIFI_TEST_PASS}" \
    || die "cmd wifi connect-network failed (AP in range? correct password?)"
}

# Current SSID from dumpsys (best-effort).
get_current_ssid() {
  local d line
  d="$(wifi_dumpsys)"
  line="$(echo "${d}" | grep -E 'mWifiInfo' | head -1 || true)"
  if [[ "${line}" =~ SSID:[[:space:]]*\"([^\"]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  line="$(adb_bin shell cmd wifi status 2>/dev/null | tr '\n' ' ' || true)"
  if [[ "${line}" =~ [Ss][Ss][Ii][Dd].*\"([^\"]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# Parse "cmd wifi list-networks" for a line containing the quoted SSID; return first integer field as network id.
network_id_for_ssid() {
  local target="$1"
  local list line id
  list="$(adb_bin shell cmd wifi list-networks 2>/dev/null || true)"
  while IFS= read -r line; do
    if ! echo "${line}" | grep -Fq "\"${target}\""; then
      echo "${line}" | grep -Fq "${target}" || continue
    fi
    id="$(echo "${line}" | grep -oE '[0-9]+' | head -1)"
    if [[ -n "${id}" ]]; then
      echo "${id}"
      return 0
    fi
  done <<< "${list}"
  return 1
}

run_cmd_wifi_disconnect() {
  if [[ "${WIFI_DISCONNECT_MODE}" == "disconnect" ]]; then
    adb_bin shell cmd wifi disconnect \
      || die "cmd wifi disconnect failed"
    return 0
  fi

  # forget-network: drops association and removes saved network for that id (connect-network adds it again later).
  local ssid nid
  ssid="$(get_current_ssid | tr -d '\r')"
  [[ -n "${ssid}" && "${ssid}" != "<unknown ssid>" ]] \
    || die "cannot read current SSID for forget-network (try cmd wifi status / dumpsys wifi)"
  if ! nid="$(network_id_for_ssid "${ssid}")"; then
    nid=""
  fi
  [[ -n "${nid}" ]] \
    || die "no list-networks entry for SSID '${ssid}' (run: adb shell cmd wifi list-networks)"
  adb_bin shell cmd wifi forget-network "${nid}" \
    || die "cmd wifi forget-network ${nid} failed"
}

run_network_tests_ordered() {
  cmd_wifi_require_subcommands
  ensure_cmd_wifi_root

  echo "-- [4] network tests (SSID=${WIFI_TEST_SSID})"
  if is_wifi_connected; then
    echo "    WiFi already associated — disconnect test first, then connect test"
    run_cmd_wifi_disconnect
    verify_wifi_disconnected
    run_cmd_wifi_connect
    verify_connected_to_test_ssid
  else
    echo "    WiFi not associated — connect test first, then disconnect test"
    run_cmd_wifi_connect
    verify_connected_to_test_ssid
    run_cmd_wifi_disconnect
    verify_wifi_disconnected
  fi
  echo "    network cmd wifi sequence OK"
}

echo "== WiFi smoke (package=${PACKAGE}) =="

need_adb
device_ready || die "No adb device ready (connect one device or set ADB_SERIAL)"

echo "-- [1] pm path"
PATH_OUT="$(adb_bin shell pm path "${PACKAGE}" 2>/dev/null || true)"
echo "${PATH_OUT}"
[[ -n "${PATH_OUT}" ]] || die "Expected installed package path, got empty output"
if ! echo "${PATH_OUT}" | grep -q "package:/system/priv-app/"; then
  DUMP="$(adb_bin shell dumpsys package "${PACKAGE}" 2>/dev/null || true)"
  echo "${DUMP}" | grep -q "PRIVATE_FLAG_PRIVILEGED\|privileged=true\|isPrivilegedApp=true" \
    || die "Expected privileged app install, got: ${PATH_OUT}"
  echo "WARN: pm path does not point at /system/priv-app, but dumpsys still marks the app privileged."
fi

echo "-- [2] NETWORK_SETTINGS granted (install permissions)"
DUMP="$(adb_bin shell dumpsys package "${PACKAGE}" 2>/dev/null || true)"
echo "${DUMP}" | grep -q "android.permission.NETWORK_SETTINGS: granted=true" \
  || die "NETWORK_SETTINGS not granted=true in dumpsys package"

echo "${DUMP}" | grep -q "PRIVATE_FLAG_PRIVILEGED\|PRIVILEGED" \
  || warn "Could not confirm PRIVILEGED flag string in dump (may still be ok)"

if [[ "${SKIP_LAUNCH}" -eq 1 ]]; then
  echo "-- [3] skipped (--skip-launch)"
  if [[ "${WITH_NETWORK_TEST}" -eq 1 ]]; then
    run_network_tests_ordered
  fi
  echo "OK: static checks passed."
  exit 0
fi

echo "-- [3] launch ${WIFI_ACTIVITY} and scan logcat for regression strings"
adb_bin logcat -c 2>/dev/null || true
adb_bin shell am start -n "${WIFI_ACTIVITY}" -a android.intent.action.MAIN >/dev/null \
  || die "am start failed"

sleep 2
LOG="$(adb_bin logcat -d -t 200 2>/dev/null || true)"

if echo "${LOG}" | grep -Eqi 'addNetworkSuggestions|ACTION_WIFI_ADD_NETWORKS|WifiNetworkSuggestion'; then
  die "Logcat contains suggestion API traces; expected WifiManager-only path"
fi

if ! adb_bin shell pidof "${PACKAGE}" >/dev/null 2>&1; then
  warn "pidof ${PACKAGE} empty; activity may have exited — check device state"
fi

if [[ "${WITH_NETWORK_TEST}" -eq 1 ]]; then
  run_network_tests_ordered
fi

echo "OK: static + launch smoke passed."
exit 0
