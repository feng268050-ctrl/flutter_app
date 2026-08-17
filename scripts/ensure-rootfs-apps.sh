#!/usr/bin/env bash
# Ensure selected APP (and optional os_settings) release bundles exist, then stage
# them into the SDK Buildroot overlay for rootfs packing (make build-rootfs).
#
# build-app writes to app/<APP>/build/bundle/release only; this script is the bridge
# into linux-sdk before ./build.sh rootfs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# Same Darwin volume / native split as Makefile apply-overlay.
run_sync_opt_app_overlay() {
	echo "ensure-rootfs-apps: sync app bundles → SDK (for rootfs pack)"
	if [[ "$(uname -s)" == Darwin && "${BUILD_BIND_MOUNT:-}" != "1" ]]; then
		SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" \
			bash /work/lws-hmi/scripts/sync-opt-app-overlay.sh --product
	else
		bash "$ROOT/scripts/sync-opt-app-overlay.sh" --product
	fi
}

ensure_app() {
	local app="$1"
	local bundle
	bundle="$(app_select_bundle_for "$app")" || die "cannot resolve bundle for APP=$app"
	if app_select_bundle_has_release "$bundle"; then
		echo "ensure-rootfs-apps: OK $app → $bundle"
		return 0
	fi
	echo "ensure-rootfs-apps: building missing APP=$app → $bundle"
	APP="$app" bash "$ROOT/scripts/build-app.sh"
	app_select_bundle_has_release "$bundle" \
		|| die "after build-app, still missing $bundle/lib/libapp.so"
}

app_select_resolve

echo "ensure-rootfs-apps: primary APP=$APP → $APP_BUNDLE_RELEASE"
ensure_app "$APP"

if app_select_os_settings_exists; then
	if [[ "$APP" != "os_settings" ]]; then
		echo "ensure-rootfs-apps: auto-include os_settings (app/os_settings present)"
	fi
	ensure_app os_settings
else
	echo "ensure-rootfs-apps: skip os_settings (app/os_settings absent)"
fi

run_sync_opt_app_overlay

echo "ensure-rootfs-apps: done"
