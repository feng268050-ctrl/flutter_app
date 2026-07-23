#!/usr/bin/env bash
# Assert pm path is empty or points at the priv-app APK; fail if /data/app/ overlay exists.
# Usage: assert-pm-priv-app-path.sh [package]
# Env: ADB_SERIAL (optional)
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

PKG="${1:-$LWS_UI_PKG}"

paths="$(adb_bin shell pm path "$PKG" 2>/dev/null | tr -d '\r' || true)"

if [[ -z "$paths" ]]; then
  echo "OK: package not installed (pm path empty)" >&2
  exit 0
fi

if echo "$paths" | grep -q '/data/app/'; then
  die "pm path still references /data/app/ (user update overlay): $(echo "$paths" | tr '\n' ' ')"
fi

if echo "$paths" | grep -q "package:${LWS_PRIV_APP_APK}"; then
  echo "OK: pm path is priv-app (${LWS_PRIV_APP_APK})" >&2
  exit 0
fi

if echo "$paths" | grep -q '/system/priv-app/'; then
  echo "WARN: pm path is priv-app but not exact ${LWS_PRIV_APP_APK}: $(echo "$paths" | tr '\n' ' ')" >&2
  exit 0
fi

die "unexpected pm path for ${PKG}: $(echo "$paths" | tr '\n' ' ')"
