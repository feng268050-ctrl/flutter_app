#!/usr/bin/env bash
# Resolve DeviceLocalHttpServer base URL for make helpers (port 5580).
set -euo pipefail

device_local_http_die() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"

DEVICE_HTTP_PORT="${DEVICE_HTTP_PORT:-5580}"

adb_serial() {
  printf '%s' "${ADB_SERIAL:-}"
}

is_emulator_serial() {
  [[ "$(adb_serial)" == emulator-* ]]
}

is_network_adb_serial() {
  [[ "$(adb_serial)" == *:* ]]
}

ensure_emulator_forward() {
  local serial emu_port
  serial="$(adb_serial)"
  [[ "${serial}" =~ ^emulator-([0-9]+)$ ]] || return 0
  emu_port="${BASH_REMATCH[1]}"
  # shellcheck source=../emulator-system-common.sh
  source "${SCRIPT_DIR}/../emulator-system-common.sh"
  setup_emulator_local_http_forward "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
}

resolve_device_local_http_base() {
  if [[ -n "${DEVICE_HTTP_URL:-}" ]]; then
    printf '%s' "${DEVICE_HTTP_URL%/}"
    return 0
  fi

  local serial host
  serial="$(adb_serial)"
  if is_emulator_serial; then
    ensure_emulator_forward || true
    printf 'http://127.0.0.1:%s' "${DEVICE_HTTP_PORT}"
    return 0
  fi
  if is_network_adb_serial; then
    host="${serial%%:*}"
    printf 'http://%s:%s' "${host}" "${DEVICE_HTTP_PORT}"
    return 0
  fi
  if [[ -n "${serial}" ]]; then
    device_local_http_die "USB adb target ${serial}: set DEVICE_HTTP_URL=http://<device-lan-ip>:${DEVICE_HTTP_PORT}"
  fi
  device_local_http_die "no adb device; set ADB_SERIAL or DEVICE_HTTP_URL"
}

probe_device_local_http() {
  local base probe_code
  base="$(resolve_device_local_http_base)"
  probe_code="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 -m 5 "${base}/lasercyber" || true)"
  if [[ "${probe_code}" != "200" ]]; then
    device_local_http_die "device local HTTP not ready at ${base} (probe HTTP ${probe_code:-000}); ensure app is running"
  fi
  printf '%s' "${base}"
}
