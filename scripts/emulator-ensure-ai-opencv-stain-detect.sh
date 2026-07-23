#!/usr/bin/env bash
# After `make emulator` boot: detect missing/outdated lens_det AI in the installed APK;
# run `make ai AI_INSTALL=1` (lens_det only, no RKNN convert) when needed.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=emulator-system-common.sh
source "${ROOT_DIR}/scripts/emulator-system-common.sh"

PKG="com.lasercyber.lws.ui"
DAEMON_ABI="lib/arm64-v8a/liblws_ai_daemon.so"
JAVA_DAEMON="AiDaemonSupervisor"

emulator_ai_install_enabled() {
  if [[ "${EMULATOR_SKIP_AI_INSTALL:-}" == "1" ]]; then
    return 1
  fi
  case "${EMULATOR_AI_INSTALL:-1}" in
    0|false|FALSE|no|NO|off|OFF) return 1 ;;
    *) return 0 ;;
  esac
}

installed_apk_has_lens_det_ai() {
  local remote_apk="$1"
  local tmp rc
  tmp="$(mktemp -d)"
  if ! adb_bin pull "${remote_apk}" "${tmp}/base.apk" >/dev/null 2>&1; then
    rm -rf "${tmp}"
    return 1
  fi
  python3 - "${tmp}/base.apk" <<'PY'
import sys
import zipfile

apk = sys.argv[1]
java_needle = b"AiDaemonSupervisor"
daemon_entry = "lib/arm64-v8a/liblws_ai_daemon.so"
with zipfile.ZipFile(apk) as z:
    dex = b"".join(z.read(n) for n in z.namelist() if n.endswith(".dex"))
    names = set(z.namelist())
ok_java = java_needle in dex
ok_native = daemon_entry in names
# Product P3 must not ship in-process libai.so
ok_no_libai = "lib/arm64-v8a/libai.so" not in names
sys.exit(0 if ok_java and ok_native and ok_no_libai else 1)
PY
  rc=$?
  rm -rf "${tmp}"
  return "${rc}"
}

ensure_emulator_ai_lens_det() {
  if ! emulator_ai_install_enabled; then
    echo "INFO: EMULATOR_AI_INSTALL disabled; skip lens_det AI install" >&2
    if ! adb_bin shell pm path "${PKG}" >/dev/null 2>&1; then
      die "${PKG} not installed on ${SERIAL}; unset EMULATOR_SKIP_AI_INSTALL or run make ai AI_INSTALL=1"
    fi
    return 0
  fi

  local remote_apk="" reason=""
  remote_apk="$(adb_bin shell pm path "${PKG}" 2>/dev/null | head -1 | cut -d: -f2 | tr -d '\r' || true)"
  if [[ -z "${remote_apk}" ]]; then
    reason="package not installed"
  elif installed_apk_has_lens_det_ai "${remote_apk}"; then
    echo "INFO: ${PKG} on ${SERIAL} already has lens_det AI (session JNI + Java); skip make ai AI_INSTALL" >&2
    return 0
  else
    reason="installed APK missing lens_det session (native and/or Java)"
  fi

  echo "INFO: ${PKG} on ${SERIAL}: ${reason}; running make ai AI_INSTALL=1 (lens_det only)" >&2
  (
    cd "${ROOT_DIR}"
    export ADB_SERIAL="${SERIAL}"
    export ANDROID_SERIAL="${SERIAL}"
    SKIP_RKNN_CONVERT=1 \
    ENABLE_LENS_DET_APP=true \
    ENABLE_RKNN_STAIN_APP=false \
      make ai AI_INSTALL=1
  )
  echo "OK: lens_det AI installed on ${SERIAL}" >&2
}

ensure_tools

# Parent `emulator-launch.sh` exports ADB_SERIAL for this emulator; honor it over .env defaults.
if [[ -n "${ADB_SERIAL:-}" ]]; then
  SERIAL="${ADB_SERIAL}"
fi

ensure_emulator_ai_lens_det
