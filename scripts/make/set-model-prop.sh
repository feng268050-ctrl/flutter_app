#!/usr/bin/env bash
# Upsert one key=value into /system/etc/model.properties on the adb target device.
# Usage: make set-prop HOST_IP=192.168.1.50  (uppercase key; written lowercase to file)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"
# shellcheck source=../model-properties-common.sh
source "${SCRIPT_DIR}/../model-properties-common.sh"

TARGET="${MODEL_PROPERTIES_PATH:-/system/etc/model.properties}"

# Make workflow vars — not model.properties keys.
_SET_PROP_SKIP=(
  RELEASE SKIP_BUNDLED_FETCH SKIP_RKNN_CONVERT RKNN_FORCE_CONVERT
  AI_INSTALL AI_GRADLE_PROPS ENABLE_RKNN_STAIN_APP ENABLE_LENS_DET_APP
  ADB_SERIAL EMULATOR_PORT EMULATOR_GPU EMULATOR_RECREATE EMULATOR_SCALE
  EMULATOR_LCD_WIDTH EMULATOR_LCD_HEIGHT EMULATOR_LCD_DENSITY
  EMULATOR_AI_INSTALL EMULATOR_SKIP_AI_INSTALL REBUILD_IMAGE
  VERSION CODE APK PKG ACTIVITY NATIVE_SRC_DIR
)

usage() {
  cat <<'EOF'
Usage:
  make set-prop <UPPERCASE_KEY>=<value>

Examples:
  make set-prop HOST_IP=192.168.1.50
  make set-prop MODEL="LaserCyber L1 Pro"
  make set-prop CAMERA_TYPE=2

Command-line keys use UPPERCASE (e.g. HOST_IP, MODEL); values are written to
/system/etc/model.properties with lowercase keys (host_ip, model, ...).
The app is restarted after write so DeviceModelConfig picks up the change.
EOF
}

is_skipped_make_var() {
  local name="$1"
  local skip
  for skip in "${_SET_PROP_SKIP[@]}"; do
    [[ "${name}" == "${skip}" ]] && return 0
  done
  return 1
}

find_prop_assignment() {
  local o key value
  PROP_KEY=""
  PROP_VALUE=""
  for o in "$@"; do
    [[ "${o}" == *=* ]] || continue
    key="${o%%=*}"
    value="${o#*=}"
    is_skipped_make_var "${key}" && continue
    [[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ ]] || continue
    if [[ -n "${PROP_KEY}" ]]; then
      die "set one property at a time (got ${PROP_KEY} and ${key})"
    fi
    PROP_KEY="${key}"
    PROP_VALUE="${value}"
  done
  [[ -n "${PROP_KEY}" ]] || return 1
}

parse_assignment() {
  find_prop_assignment "$@" || {
    usage
    die "expected one UPPERCASE_KEY=value (example: make set-prop HOST_IP=192.168.1.50)"
  }
  # GNU make escapes spaces in MAKEOVERRIDES (e.g. MODEL=LaserCyber\ L1\ Pro).
  PROP_VALUE="${PROP_VALUE//\\ / }"
  KEY="$(printf '%s' "${PROP_KEY}" | tr '[:upper:]' '[:lower:]')"
  VALUE="${PROP_VALUE}"
}

root_exec() {
  if adb_bin shell "$1" >/dev/null 2>&1; then
    return 0
  fi
  adb_bin shell 'command -v su >/dev/null 2>&1' >/dev/null 2>&1 || return 1
  adb_bin shell su 0 sh -c "$1" </dev/null
}

ensure_root_context() {
  adb_bin root >/dev/null 2>&1 || true
  sleep 1
  adb_bin wait-for-device >/dev/null 2>&1 || true
  if adb_bin shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'; then
    return 0
  fi
  adb_bin shell 'command -v su >/dev/null 2>&1' 2>/dev/null || return 1
  adb_bin shell su 0 id </dev/null 2>/dev/null | tr -d '\r' | grep -q 'uid=0'
}

system_mount_line() {
  adb_bin shell 'mount | grep " /system "' 2>/dev/null | tr -d '\r' | head -n 1 || true
}

system_is_rw_by_mount() {
  local line
  line="$(system_mount_line)"
  [[ -n "${line}" ]] || return 1
  [[ "$line" == *"(rw"* || "$line" == *" rw,"* ]]
}

ensure_system_writable() {
  if system_is_rw_by_mount; then
    return 0
  fi
  echo "INFO: /system is read-only; attempting adb remount..." >&2
  adb_bin remount >/dev/null 2>&1 || true
  sleep 1
  system_is_rw_by_mount || die "/system is not writable (run make prepare or make emulator first)"
}

parse_assignment "$@"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"
ensure_root_context || die "need adb root or su 0 to write ${TARGET}"
ensure_system_writable

pulled="$(mktemp)"
merged="$(mktemp)"
trap 'rm -f "${pulled}" "${merged}"' EXIT

if adb_bin pull "${TARGET}" "${pulled}" >/dev/null 2>&1 && [[ -s "${pulled}" ]]; then
  cp "${pulled}" "${merged}"
else
  : > "${merged}"
fi

upsert_model_property_in_file "${KEY}" "${VALUE}" "${merged}"

echo "INFO: writing ${KEY}=${VALUE} to ${TARGET} (from ${PROP_KEY})..." >&2
adb_bin push "${merged}" "${TARGET}" >/dev/null \
  || die "failed to push ${TARGET}"
adb_bin shell chmod 0644 "${TARGET}" >/dev/null 2>&1 || true
adb_bin shell chown root:root "${TARGET}" >/dev/null 2>&1 || true
adb_bin shell restorecon "${TARGET}" >/dev/null 2>&1 || true

echo "OK: ${KEY}=${VALUE} -> ${TARGET}"
echo "INFO: relaunching app to reload model.properties..." >&2
"${SCRIPT_DIR}/relaunch-app.sh"
