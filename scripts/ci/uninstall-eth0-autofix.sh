#!/usr/bin/env bash
# Remove legacy system eth0 self-heal (fixed 192.168.1.10) installed by install-eth0-autofix.sh.
# Requires root on device. Eth0 is then managed by the app (CameraEth0AddressPlanner).
#
# Usage:
#   ADB_SERIAL=<serial> ./scripts/ci/uninstall-eth0-autofix.sh
#   REBOOT=1 ADB_SERIAL=<serial> ./scripts/ci/uninstall-eth0-autofix.sh
#
# Env:
#   ADB_SERIAL  optional adb -s target (required when multiple devices)
#   REBOOT=1    reboot after uninstall (recommended so init stops respawning)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

adb_bin() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    command adb -s "${ADB_SERIAL}" "$@"
  else
    command adb "$@"
  fi
}

root_exec() {
  if adb_bin shell sh -c "$1" 2>/dev/null; then
    return 0
  fi
  adb_bin shell 'command -v su >/dev/null 2>&1' 2>/dev/null || return 1
  adb_bin shell su 0 sh -c "$1" </dev/null 2>/dev/null
}

need_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
}

device_ready() {
  local out
  out="$(adb_bin devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  [[ -n "$out" ]] || die "No adb device in 'device' state"
  if [[ -z "${ADB_SERIAL:-}" ]]; then
    local n
    n="$(echo "$out" | wc -l | tr -d ' ')"
    [[ "$n" -eq 1 ]] || die "Multiple devices; set ADB_SERIAL. Found: $(echo "$out" | tr '\n' ' ')"
  else
    echo "$out" | grep -qx "${ADB_SERIAL}" || die "Device ${ADB_SERIAL} not in 'device' state"
  fi
}

file_exists() {
  adb_bin shell "[ -e '$1' ]" 2>/dev/null
}

need_adb
device_ready

target="${ADB_SERIAL:-default}"
echo "== uninstall legacy eth0 autofix (device=${target})" >&2

echo "INFO: stopping lws-eth0-selfheal..." >&2
root_exec "pkill -f lws-eth0-selfheal.sh 2>/dev/null || true" || true

paths=(
  /system/etc/init/lws-eth0-init.rc
  /system/bin/lws-eth0-selfheal.sh
  /data/local/lws-eth0-selfheal.conf
  /data/local/tmp/lws-eth0-selfheal.sh
  /data/local/tmp/lws-eth0-init.rc
)

for p in "${paths[@]}"; do
  if file_exists "$p"; then
    root_exec "rm -f '$p'" || die "failed to remove $p (need root?)"
    echo "INFO: removed $p" >&2
  else
    echo "INFO: not present: $p" >&2
  fi
done

if adb_bin shell pgrep -f lws-eth0-selfheal 2>/dev/null | tr -d '\r' | grep -q .; then
  die "lws-eth0-selfheal process still running after pkill"
fi
echo "OK: no lws-eth0-selfheal process" >&2

echo "INFO: eth0 (app will reconfigure on next launch):" >&2
adb_bin shell ip addr show eth0 2>/dev/null | tr -d '\r' || true

if [[ "${REBOOT:-}" == "1" ]]; then
  echo "INFO: rebooting..." >&2
  adb_bin reboot
  adb_bin wait-for-device
  for _ in $(seq 1 60); do
    boot="$(adb_bin shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "$boot" == "1" ]]; then
      echo "OK: boot completed; legacy eth0 autofix removed." >&2
      exit 0
    fi
    sleep 2
  done
  die "device did not report sys.boot_completed=1 after reboot"
fi

echo "OK: legacy eth0 autofix removed (set REBOOT=1 to reboot and clear init hook)." >&2
