#!/usr/bin/env bash
# Ensure selected APP (and optional factory_test) release trees exist in fs-overlay.
# Used by make build-rootfs before packing. Builds missing apps via build-app.sh.
#
# One rootfs: at most one HMI (*_hmi → /opt/hmi) plus optional factory_test (/opt/factory_test).
# Selecting APP=cnc_hmi replaces /opt/hmi with that product (same install path as lws_hmi).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
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
}

app_select_resolve

echo "ensure-rootfs-apps: primary APP=$APP → $OVERLAY_APP"
ensure_app "$APP"

if app_select_factory_test_exists; then
	if [[ "$APP" != "factory_test" ]]; then
		echo "ensure-rootfs-apps: auto-include factory_test (app/factory_test present)"
	fi
	ensure_app factory_test
else
	echo "ensure-rootfs-apps: skip factory_test (app/factory_test absent)"
fi

echo "ensure-rootfs-apps: done"
