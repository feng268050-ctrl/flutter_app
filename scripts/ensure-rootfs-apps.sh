#!/usr/bin/env bash
# Ensure selected APP (and optional os_settings) release trees exist in fs-overlay.
# Used by make build-rootfs before packing. Builds missing apps via build-app.sh.
#
# One rootfs: at most one HMI (*_hmi → /opt/hmi) plus optional os_settings (/opt/os_settings).
# Selecting APP=cnc_hmi replaces /opt/hmi with that product (same install path as lws_hmi).
#
# If any app was built here, run one apply-overlay so /opt/* lands in the SDK before pack.
# When trees already exist, this script does not apply-overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

BUILT_ANY=0

# Same Darwin volume / native split as Makefile apply-overlay.
run_apply_overlay() {
	echo "ensure-rootfs-apps: apply-overlay (new app tree → SDK)"
	if [[ "$(uname -s)" == Darwin && "${BUILD_BIND_MOUNT:-}" != "1" ]]; then
		SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" \
			bash /work/lws-hmi/scripts/apply-overlay.sh
	else
		bash "$ROOT/scripts/apply-overlay.sh"
	fi
}

ensure_app() {
	local app="$1"
	local dest
	dest="$(app_select_overlay_for "$app")" || die "cannot resolve overlay for APP=$app"
	if app_select_overlay_has_release "$dest"; then
		echo "ensure-rootfs-apps: OK $app → $dest"
		return 0
	fi
	echo "ensure-rootfs-apps: building missing APP=$app → $dest"
	APP="$app" bash "$ROOT/scripts/build-app.sh"
	app_select_overlay_has_release "$dest" \
		|| die "after build-app, still missing $dest/lib/libapp.so"
	BUILT_ANY=1
}

app_select_resolve

echo "ensure-rootfs-apps: primary APP=$APP → $OVERLAY_APP"
ensure_app "$APP"

if app_select_os_settings_exists; then
	if [[ "$APP" != "os_settings" ]]; then
		echo "ensure-rootfs-apps: auto-include os_settings (app/os_settings present)"
	fi
	ensure_app os_settings
else
	echo "ensure-rootfs-apps: skip os_settings (app/os_settings absent)"
fi

if [[ "$BUILT_ANY" -eq 1 ]]; then
	run_apply_overlay
fi

echo "ensure-rootfs-apps: done"
