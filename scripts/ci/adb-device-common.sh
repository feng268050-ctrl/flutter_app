#!/usr/bin/env bash
# Shared adb helpers for scripts/ci (prepare, install reboot, etc.).
# Source this file; callers must define die() before sourcing if not already present.

adb_bin() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    command adb -s "${ADB_SERIAL}" "$@"
  else
    command adb "$@"
  fi
}

is_network_adb_serial() {
  [[ -n "${ADB_SERIAL:-}" && "${ADB_SERIAL}" == *:* ]]
}

try_adb_connect() {
  is_network_adb_serial || return 0
  adb connect "${ADB_SERIAL}" >/dev/null 2>&1 || true
}

adb_target_state() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    adb devices 2>/dev/null | awk -v s="${ADB_SERIAL}" '$1 == s {print $2; exit}'
    return 0
  fi
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $2; exit}'
}

adb_device_ready() {
  [[ "$(adb_target_state || true)" == "device" ]]
}

ensure_adb_ready() {
  if adb_device_ready; then
    return 0
  fi
  if is_network_adb_serial; then
    echo "INFO: ${ADB_SERIAL} not in 'device' state; running adb connect..." >&2
    try_adb_connect
    sleep 1
    adb_device_ready && return 0
  fi
  return 1
}

# After adb root / reboot / pm clear — especially on network adb — wait for a stable session.
wait_adb_stable() {
  local i state
  for i in $(seq 1 45); do
    try_adb_connect
    adb_bin wait-for-device >/dev/null 2>&1 || true
    state="$(adb_target_state || true)"
    if [[ "${state}" == "device" ]]; then
      return 0
    fi
    if [[ $((i % 5)) -eq 1 ]]; then
      echo "INFO: waiting for adb stable (state=${state:-missing}); attempt ${i}/45..." >&2
    fi
    sleep 2
  done
  return 1
}

ensure_adb_ready_stable() {
  wait_adb_stable || return 1
  ensure_adb_ready
}

adb_has_root() {
  adb_bin shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'
}

ensure_adb_root() {
  if adb_has_root; then
    return 0
  fi
  echo "INFO: adb root..." >&2
  adb_bin root >/dev/null 2>&1 || true
  sleep 2
  wait_adb_stable || return 1
  adb_has_root
}

wait_boot_after_reboot() {
  local i boot state
  echo "INFO: waiting 5s after reboot before adb reconnect attempts..." >&2
  sleep 5
  if is_network_adb_serial; then
    echo "INFO: waiting for adb connection to ${ADB_SERIAL} (re-enable remote debugging on device after reboot if needed)..." >&2
  else
    echo "INFO: waiting for adb connection (re-enable debugging on device after reboot if needed)..." >&2
  fi
  for i in $(seq 1 120); do
    try_adb_connect
    state="$(adb_target_state || true)"
    if [[ "${state}" == "device" ]]; then
      boot="$(adb_bin shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "$boot" == "1" ]]; then
        echo "INFO: adb connected and boot completed." >&2
        return 0
      fi
      if [[ $((i % 5)) -eq 1 ]]; then
        echo "INFO: adb connected; waiting for boot completion..." >&2
      fi
    elif [[ $((i % 5)) -eq 1 ]]; then
      if is_network_adb_serial; then
        echo "INFO: adb reconnect pending (${ADB_SERIAL}); attempt ${i}/120..." >&2
      else
        echo "INFO: adb device not ready; attempt ${i}/120..." >&2
      fi
    fi
    sleep 3
  done
  die "device did not reconnect via adb or report sys.boot_completed=1 after reboot"
}
