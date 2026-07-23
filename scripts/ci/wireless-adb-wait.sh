#!/usr/bin/env bash
# Wait for wireless (network) adb to become ready after reboot or adbd restart.
# Usage: wireless-adb-wait.sh
# Env: ADB_SERIAL must be host:port; WIRELESS_ADB_WAIT_ITER (default 90)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

if ! is_network_adb_serial; then
  ensure_adb_ready_stable || die "adb device not ready"
  exit 0
fi

max_iter="${WIRELESS_ADB_WAIT_ITER:-90}"
echo "INFO: wireless adb target ${ADB_SERIAL} — waiting for reconnect (up to ~$((max_iter * 2))s)..." >&2
echo "INFO: if this hangs, on the device: Settings → Developer options → Wireless debugging → ON, then re-pair or note IP:port" >&2

i=0
while (( i < max_iter )); do
  i=$((i + 1))
  try_adb_connect
  adb_bin wait-for-device >/dev/null 2>&1 || true
  state="$(adb_target_state || true)"
  if [[ "${state}" == "device" ]]; then
    boot="$(adb_bin shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "${boot}" == "1" ]]; then
      echo "INFO: wireless adb ready (boot completed)." >&2
      exit 0
    fi
    if [[ $((i % 5)) -eq 1 ]]; then
      echo "INFO: wireless adb connected; waiting for boot_completed..." >&2
    fi
  elif [[ $((i % 5)) -eq 1 ]]; then
    echo "INFO: wireless adb pending (state=${state:-missing}); attempt ${i}/${max_iter}..." >&2
  fi
  sleep 2
done

die "wireless adb did not become ready — re-enable Wireless debugging on device and run: make install-cloud-resume VERSION=..."
