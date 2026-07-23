#!/usr/bin/env bash
# Clear user-update overlay so pm path resolves to system priv-app (cloud install).
# Usage: ensure-cloud-pm-priv-app.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

echo "INFO: ensuring priv-app path (no /data/app/ overlay)..." >&2

strip_priv_app_user_update_overlay "$LWS_UI_PKG"
"${SCRIPT_DIR}/purge-package-cache-for-pkg.sh" "$LWS_UI_PKG"
"${SCRIPT_DIR}/assert-pm-priv-app-path.sh" "$LWS_UI_PKG"

echo "OK: priv-app PM path ready" >&2
