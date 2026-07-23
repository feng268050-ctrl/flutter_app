#!/usr/bin/env bash
# Cloud VERSION= install pipeline (make install VERSION=x.y.z).
#
# Phases (INSTALL_PHASE):
#   full   — default: push + reboot + resume (USB-friendly)
#   push   — fetch, downgrade purge, priv-app push only (no reboot)
#   resume — after reboot / wireless reconnect: PM sync, verify, launch
#
# Wireless workflow:
#   make install VERSION=1.0.30 INSTALL_SKIP_REBOOT=1 ADB_SERIAL=192.168.x.x:5555
#   # reboot device; re-enable wireless debugging on device
#   make install-cloud-resume VERSION=1.0.30 ADB_SERIAL=192.168.x.x:5555
#
# Env: INSTALL_RELEASE, INSTALL_STRICT=1, INSTALL_SKIP_REBOOT=1, INSTALL_PHASE, ADB_SERIAL, VERSION
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$ROOT"

# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-state.sh
source "${SCRIPT_DIR}/cloud-install-state.sh"

export LWS_CLOUD_CACHE_ROOT="${ROOT}/build/cache/lws-app"
mkdir -p "${LWS_CLOUD_CACHE_ROOT}"

VERSION="${VERSION:-}"
[[ -n "$VERSION" ]] || die "VERSION is required"

INSTALL_PHASE="${INSTALL_PHASE:-full}"
if [[ "${INSTALL_SKIP_REBOOT:-}" == "1" ]]; then
  INSTALL_PHASE="push"
fi

export INSTALL_STRICT=1

chmod +x \
  scripts/ci/fetch-lws-app-package.sh \
  scripts/ci/purge-pm-before-downgrade.sh \
  scripts/ci/purge-pm-after-downgrade.sh \
  scripts/ci/verify-priv-app-install.sh \
  scripts/ci/install-priv-app.sh \
  scripts/ci/reboot-and-wait-boot.sh \
  scripts/ci/sync-pm-after-priv-app-install.sh \
  scripts/ci/maybe-emulator-forward-local-http.sh \
  scripts/ci/apk-version-read.sh \
  scripts/ci/installed-apk-version-read.sh \
  scripts/ci/purge-package-cache-for-pkg.sh \
  scripts/ci/assert-pm-priv-app-path.sh \
  scripts/ci/ensure-cloud-pm-priv-app.sh \
  scripts/ci/resync-pm-from-priv-app-apk.sh \
  scripts/ci/wireless-adb-wait.sh \
  scripts/ci/cloud-install-common.sh \
  scripts/ci/cloud-install-state.sh

cloud_install_launch_app() {
  if [[ -n "${ADB_SERIAL:-}" ]]; then
    ADB_CMD=(adb -s "$ADB_SERIAL")
  else
    ADB_CMD=(adb)
  fi
  echo "INFO: launching app..." >&2
  "${ADB_CMD[@]}" shell am start -W -n com.lasercyber.lws.ui/.activitys.SplashActivity >/dev/null 2>&1 || true
}

cloud_install_resume() {
  local cloud_apk="$1"
  ./scripts/ci/wireless-adb-wait.sh
  INSTALL_STRICT=1 ./scripts/ci/sync-pm-after-priv-app-install.sh "$cloud_apk"
  ./scripts/ci/ensure-cloud-pm-priv-app.sh
  ./scripts/ci/purge-pm-after-downgrade.sh "$cloud_apk"
  wait_adb_stable >/dev/null 2>&1 || true
  ./scripts/ci/verify-priv-app-install.sh "$cloud_apk"
  cloud_install_launch_app
  cloud_install_clear_state
  ./scripts/ci/maybe-emulator-forward-local-http.sh
  echo "OK: cloud install complete (resume)." >&2
}

# Push priv-app APK and persist host path in .install-state.env.
# Do NOT capture this function's stdout: adb push/root print progress there and
# pollute command substitution (seen as ERROR: APK not found: Success).
cloud_install_push() {
  rm -f "${LWS_CLOUD_CACHE_ROOT}/.cloud-was-downgrade"
  local cloud_apk
  cloud_apk="$(./scripts/ci/fetch-lws-app-package.sh "$VERSION")"
  [[ -f "$cloud_apk" ]] || die "cloud APK missing after fetch: $cloud_apk"

  ./scripts/ci/purge-pm-before-downgrade.sh "$cloud_apk"
  ./scripts/ci/ensure-cloud-pm-priv-app.sh
  # adb push / remount chatter must not leak to any caller capturing stdout
  ./scripts/ci/install-priv-app.sh "$cloud_apk" >/dev/null
  cloud_install_save_state "$cloud_apk" "$VERSION"
}

cloud_install_resolve_apk() {
  local cloud_apk=""
  if cloud_install_load_state "$VERSION"; then
    cloud_apk="$CLOUD_APK"
  else
    cloud_apk="$(./scripts/ci/fetch-lws-app-package.sh "$VERSION")"
    echo "WARN: no install state file; using freshly fetched APK for resume metadata" >&2
  fi
  [[ -f "$cloud_apk" ]] || die "APK not found for resume: $cloud_apk"
  printf '%s\n' "$cloud_apk"
}

case "$INSTALL_PHASE" in
  push)
    cloud_install_push
    echo "" >&2
    echo "OK: cloud push complete (priv-app APK on device, no reboot)." >&2
    echo "Next (wireless): reboot device → re-enable Wireless debugging → same IP:port → then:" >&2
    echo "  make install-cloud-resume VERSION=${VERSION} ADB_SERIAL=${ADB_SERIAL:-<host:port>}" >&2
    ;;
  resume)
    cloud_apk="$(cloud_install_resolve_apk)"
    cloud_install_resume "$cloud_apk"
    ;;
  full|*)
    cloud_install_push
    cloud_apk="$(cloud_install_resolve_apk)"
    ./scripts/ci/reboot-and-wait-boot.sh
    cloud_install_resume "$cloud_apk"
    echo "OK: cloud install complete." >&2
    ;;
esac
