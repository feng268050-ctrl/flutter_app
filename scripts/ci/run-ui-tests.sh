#!/usr/bin/env bash
# Run instrumentation tests against the already-installed system app, without
# letting Gradle reinstall the target APK (avoids signature conflict).
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

adb_bin() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    command adb -s "${ADB_SERIAL}" "$@"
  else
    command adb "$@"
  fi
}

APP_PACKAGE="${APP_PACKAGE:-com.lasercyber.lws.ui}"
TEST_PACKAGE="${TEST_PACKAGE:-${APP_PACKAGE}.test}"
TEST_RUNNER="${TEST_RUNNER:-androidx.test.runner.AndroidJUnitRunner}"
TEST_APK="${TEST_APK:-app/build/outputs/apk/androidTest/release/app-release-androidTest.apk}"

command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
adb_bin get-state >/dev/null 2>&1 || die "adb device not ready"

echo "== build release androidTest apk" >&2
./gradlew :app:assembleReleaseAndroidTest --no-daemon
[[ -f "${TEST_APK}" ]] || die "androidTest APK not found: ${TEST_APK}"

echo "== ensure target app exists (system/priv-app expected)" >&2
TARGET_PATH="$(adb_bin shell pm path "${APP_PACKAGE}" 2>/dev/null | tr -d '\r' || true)"
[[ -n "${TARGET_PATH}" ]] || die "target app ${APP_PACKAGE} is not installed"
if ! echo "${TARGET_PATH}" | grep -q "package:/system/priv-app/"; then
  DUMP="$(adb_bin shell dumpsys package "${APP_PACKAGE}" 2>/dev/null | tr -d '\r' || true)"
  echo "${DUMP}" | grep -q "PRIVATE_FLAG_PRIVILEGED\|privileged=true\|isPrivilegedApp=true" \
    || die "target app ${APP_PACKAGE} is not marked privileged: ${TARGET_PATH}"
  echo "WARN: pm path does not point at /system/priv-app, but dumpsys still marks the app privileged." >&2
fi

echo "== install test apk only: ${TEST_APK}" >&2
adb_bin uninstall "${TEST_PACKAGE}" >/dev/null 2>&1 || true
adb_bin install -r -t "${TEST_APK}" >/dev/null

echo "== run instrumentation: ${TEST_PACKAGE}/${TEST_RUNNER}" >&2
adb_bin shell am instrument -w "${TEST_PACKAGE}/${TEST_RUNNER}"
