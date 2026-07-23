#!/usr/bin/env bash
# Clear process-library rows + version marker, then relaunch so BundledLibraryBootstrap re-imports APK assets.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../ci/adb-device-common.sh
source "${SCRIPT_DIR}/../ci/adb-device-common.sh"

PKG="${PKG:-com.lasercyber.lws.ui}"
DB_NAME="${DB_NAME:-lws_ui}"
DB_REL="databases/${DB_NAME}"
DB_ABS="/data/data/${PKG}/${DB_REL}"
LEGACY_DIR="/data/data/${PKG}/files/bundled-libraries/process-library"

RESET_SQL="DELETE FROM t_process_parameters_data WHERE dataType IN (0, 1, 2); UPDATE t_device_info SET processLibVersion='';"

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

run_sql_as_root() {
  root_exec "command -v sqlite3 >/dev/null 2>&1" \
    || die "sqlite3 not found on device (need adb root or su 0)"
  root_exec "test -f '${DB_ABS}'" \
    || die "database not found at ${DB_ABS} (install app first)"
  root_exec "sqlite3 '${DB_ABS}' \"${RESET_SQL}\""
}

run_sql_as_app() {
  adb_bin shell run-as "$PKG" sh -c "
    command -v sqlite3 >/dev/null 2>&1 || exit 10
    test -f '${DB_REL}' || exit 11
    sqlite3 '${DB_REL}' \"${RESET_SQL}\"
  " >/dev/null 2>&1 || {
    local rc=$?
    case "$rc" in
      10) die "sqlite3 not found in app context (try adb root on emulator)" ;;
      11) die "database not found at ${DB_REL} (install app first)" ;;
      *) die "failed to reset process library via run-as (exit ${rc})" ;;
    esac
  }
}

remove_legacy_dir() {
  if ensure_root_context; then
    root_exec "rm -rf '${LEGACY_DIR}'" >/dev/null 2>&1 || true
    return 0
  fi
  adb_bin shell run-as "$PKG" rm -rf "files/bundled-libraries/process-library" >/dev/null 2>&1 || true
}

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready || die "No adb device in 'device' state (connect one device or set ADB_SERIAL)"

echo "INFO: stopping ${PKG}..." >&2
adb_bin shell am force-stop "$PKG" >/dev/null 2>&1 || true

echo "INFO: clearing process-library rows (dataType 0/1/2) and processLibVersion..." >&2
if ensure_root_context; then
  run_sql_as_root
else
  run_sql_as_app
fi

echo "INFO: removing legacy bundled-libraries/process-library cache (if any)..." >&2
remove_legacy_dir

echo "INFO: relaunching ${PKG} for bundled process-library import..." >&2
"${SCRIPT_DIR}/relaunch-app.sh"
echo "OK: process-library reset complete; app relaunched for bundled import."
