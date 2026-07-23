#!/usr/bin/env bash
# Verify priv-app install matches target APK before launch.
# Usage: verify-priv-app-install.sh <host-apk>
# Env: ADB_SERIAL (optional)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

HOST_APK="${1:-}"
[[ -n "$HOST_APK" && -f "$HOST_APK" ]] || die "usage: $0 <host-apk>"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
ensure_adb_ready_stable || die "No adb device in 'device' state (connect USB or re-enable wireless debugging)"

TARGET_CODE="$("${SCRIPT_DIR}/apk-version-read.sh" "$HOST_APK" versionCode)"
TARGET_NAME="$("${SCRIPT_DIR}/apk-version-read.sh" "$HOST_APK" versionName)"
TARGET_PKG="$("${SCRIPT_DIR}/apk-version-read.sh" "$HOST_APK" package)"

[[ "$TARGET_PKG" == "$LWS_UI_PKG" ]] || die "unexpected package in APK: ${TARGET_PKG} (expected ${LWS_UI_PKG})"

"${SCRIPT_DIR}/assert-pm-priv-app-path.sh" "$LWS_UI_PKG"

paths="$(adb_bin shell pm path "$LWS_UI_PKG" 2>/dev/null | tr -d '\r' || true)"
echo "$paths" | grep -q "package:${LWS_PRIV_APP_APK}" \
  || die "pm path missing ${LWS_PRIV_APP_APK}: ${paths:-<empty>}"

adb_bin shell test -s "${LWS_PRIV_APP_APK}" \
  || die "device APK missing or empty: ${LWS_PRIV_APP_APK}"

INSTALLED_CODE="$("${SCRIPT_DIR}/installed-apk-version-read.sh" "$LWS_UI_PKG" versionCode)"
INSTALLED_NAME="$("${SCRIPT_DIR}/installed-apk-version-read.sh" "$LWS_UI_PKG" versionName)"

[[ "$INSTALLED_CODE" == "$TARGET_CODE" ]] \
  || die "versionCode mismatch: device=${INSTALLED_CODE:-<empty>} target=${TARGET_CODE}"

[[ "$INSTALLED_NAME" == "$TARGET_NAME" ]] \
  || die "versionName mismatch: device=${INSTALLED_NAME:-<empty>} target=${TARGET_NAME}"

# Priv-app loads JNI from legacyNativeLibraryDir (.../LwsUI/lib/<abi>).
# Missing libserial_port.so → Modbus INIT_FAILED → boot self-check SKIPPED.
PRIV_LIB_SERIAL=/system/priv-app/LwsUI/lib/arm64/libserial_port.so
adb_bin shell su 0 test -f "$PRIV_LIB_SERIAL" \
  || die "native lib missing on device: ${PRIV_LIB_SERIAL} (re-run install-priv-app.sh)"

echo "OK: verify passed (${TARGET_NAME}+${TARGET_CODE}, priv-app path + libserial_port)" >&2
