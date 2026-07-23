#!/usr/bin/env bash
# Push a release APK to /system/priv-app/LwsUI/LwsUI.apk and stage native libs.
# Requires adb root (or su) and writable /system — run scripts/ci/prepare-device.sh first.
# Note: raw priv-app replace alone may not refresh PackageManager on some ROMs; `make install`
# also runs scripts/ci/sync-pm-after-priv-app-install.sh after reboot (pm install on this APK path).
#
# Native libs: PackageManager for priv-app uses legacyNativeLibraryDir=/system/priv-app/LwsUI/lib.
# Copying only the APK leaves that directory empty → UnsatisfiedLinkError (e.g. libserial_port.so)
# and Modbus/boot self-check SKIPPED. This script extracts lib/<apk-abi>/*.so → lib/<device-abi>/.
#
# Usage: install-priv-app.sh <path-to.apk>
# Env: ADB_SERIAL (optional, same as other scripts/ci tools)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"

PRIV_APP_DIR=/system/priv-app/LwsUI
PRIV_APP_APK="${PRIV_APP_DIR}/LwsUI.apk"
# Android device ABI dir under nativeLibraryDir (APK uses arm64-v8a).
DEVICE_ABI_DIR=arm64
APK_ABI_DIR=arm64-v8a

clear_user_update() {
  local pkg="com.lasercyber.lws.ui"
  echo "== clear any stale system-app update: ${pkg}" >&2
  adb_bin shell pm uninstall-system-updates "${pkg}" >/dev/null 2>&1 || true
  adb_bin shell cmd package uninstall-system-updates "${pkg}" >/dev/null 2>&1 || true
}

# Extract APK lib/<apk-abi>/*.so and push to ${PRIV_APP_DIR}/lib/<device-abi>/.
install_native_libs_from_apk() {
  local apk="$1"
  command -v unzip >/dev/null 2>&1 || die "unzip not found in PATH"

  local tmp host_lib device_lib remote_tmp so base n=0
  tmp="$(mktemp -d)"
  echo "== extract native libs from APK (${APK_ABI_DIR} → ${DEVICE_ABI_DIR})" >&2
  if ! unzip -q -o "$apk" "lib/${APK_ABI_DIR}/*.so" -d "$tmp"; then
    rm -rf "$tmp"
    die "no lib/${APK_ABI_DIR}/*.so in APK: $apk"
  fi
  host_lib="${tmp}/lib/${APK_ABI_DIR}"
  if [[ ! -d "$host_lib" ]]; then
    rm -rf "$tmp"
    die "extract failed: missing $host_lib"
  fi
  shopt -s nullglob
  local sos=( "$host_lib"/*.so )
  shopt -u nullglob
  if [[ "${#sos[@]}" -eq 0 ]]; then
    rm -rf "$tmp"
    die "no .so files under lib/${APK_ABI_DIR} in $apk"
  fi

  device_lib="${PRIV_APP_DIR}/lib/${DEVICE_ABI_DIR}"
  remote_tmp=/data/local/tmp/lws-priv-app-libs
  adb_bin shell su 0 mkdir -p "$device_lib" "$remote_tmp"
  # Clear prior staged libs (explicit find: toybox ash often fails 'dir'/*.so globs → empty cp).
  adb_bin shell su 0 sh -c \
    "find '${device_lib}' '${remote_tmp}' -maxdepth 1 -type f -name '*.so' -delete 2>/dev/null; true" \
    >/dev/null 2>&1 || true

  # Per-file copy: avoid device-side wildcards (cp: Need 2 arguments on RK/toolboxes).
  for so in "${sos[@]}"; do
    base="$(basename "$so")"
    adb_bin push "$so" "${remote_tmp}/${base}" >/dev/null 2>&1 \
      || die "adb push failed: ${base}"
    adb_bin shell su 0 cp "${remote_tmp}/${base}" "${device_lib}/${base}" \
      || die "cp to ${device_lib}/${base} failed"
    adb_bin shell su 0 chmod 0644 "${device_lib}/${base}"
    adb_bin shell su 0 chown root:root "${device_lib}/${base}" >/dev/null 2>&1 || true
    n=$((n + 1))
  done
  rm -rf "$tmp"
  adb_bin shell su 0 rm -rf "$remote_tmp" >/dev/null 2>&1 || true

  adb_bin shell su 0 test -f "${device_lib}/libserial_port.so" \
    || die "missing ${device_lib}/libserial_port.so after install (Modbus will fail)"
  echo "OK: staged ${n} native libs → ${device_lib}" >&2
}

[[ "${1:-}" ]] || die "usage: $0 <path-to.apk>"
APK="$1"
[[ -f "$APK" ]] || die "APK not found: $APK"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"

echo "== install priv-app: $APK -> ${PRIV_APP_APK}" >&2
adb_bin root 2>/dev/null || true
sleep 1
adb_bin wait-for-device 2>/dev/null || true
clear_user_update

if ! adb_bin shell su 0 id 2>/dev/null | grep -q uid=0; then
  die "need adb root or su 0 to write /system/priv-app"
fi

# adb remount handles overlayfs (emulator -writable-system, or physical device after make prepare).
# Fall back to shell-level mount for older ROMs that don't support the adb command.
adb_bin remount >/dev/null 2>&1 \
  || adb_bin shell su 0 sh -c 'mount -o remount,rw /system >/dev/null 2>&1 || mount -o remount,rw / >/dev/null 2>&1' 2>/dev/null \
  || true
adb_bin shell su 0 test -w /system/priv-app 2>/dev/null \
  || die "/system/priv-app is not writable — run 'make prepare' first (physical device) or start the emulator with 'make emulator'"
adb_bin shell su 0 mkdir -p "$PRIV_APP_DIR"
adb_bin push "$APK" /data/local/tmp/LwsUI.apk >/dev/null
adb_bin shell su 0 cp /data/local/tmp/LwsUI.apk "$PRIV_APP_APK"
adb_bin shell su 0 chmod 0644 "$PRIV_APP_APK"
adb_bin shell su 0 chown root:root "$PRIV_APP_APK" 2>/dev/null || true
adb_bin shell rm -f /data/local/tmp/LwsUI.apk 2>/dev/null || true

install_native_libs_from_apk "$APK"

echo "OK: installed ${PRIV_APP_APK} (+ native libs)" >&2
