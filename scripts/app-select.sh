#!/usr/bin/env bash
# Resolve Make/env APP → Flutter project dir + overlay/device install prefix.
# Source from host scripts (requires ROOT). Does not build anything.
#
# Convention:
#   - HMI apps are named with suffix `_hmi` (e.g. lws_hmi, cnc_hmi).
#   - All HMI apps install to /opt/hmi so hmi.service can launch them.
#   - One rootfs has at most one HMI app tree at /opt/hmi (+ optional factory_test).
#   - Non-HMI apps (e.g. factory_test) install to /opt/<APP>.
#
# shellcheck shell=bash

# True if APP id is an HMI product (suffix _hmi).
app_select_is_hmi() {
	local app="$1"
	[[ "$app" == *_hmi ]]
}

# Install dir basename under /opt (hmi for *_hmi, else APP id).
app_select_opt_name() {
	local app="$1"
	if app_select_is_hmi "$app"; then
		printf '%s\n' hmi
	else
		printf '%s\n' "$app"
	fi
}

# Usage: app_select_resolve   # reads APP from env; defaults to lws_hmi
# Exports:
#   APP, APP_DIR, APP_OPT_NAME, OVERLAY_APP, DEVICE_APP, APP_IS_HMI
#   APP_FIRMWARE_DIR (output/firmware/<APP>), APP_ROOTFS_IMG
#   OVERLAY_OPT_ROOT (…/rootfs-overlay/opt)
#   APP_IS_PRODUCT_HMI — alias of APP_IS_HMI (compat)
app_select_resolve() {
	local root="${ROOT:-}"
	local app opt_name overlay_opt

	[[ -n "$root" ]] || {
		echo "ERROR: app_select_resolve: ROOT is unset" >&2
		return 1
	}

	app="${APP:-lws_hmi}"
	# Trim whitespace; reject path separators / traversal.
	app="${app#"${app%%[![:space:]]*}"}"
	app="${app%"${app##*[![:space:]]}"}"
	if [[ -z "$app" ]]; then
		app=lws_hmi
	fi
	case "$app" in
	*/* | *\\* | .* | *..*)
		echo "ERROR: invalid APP='$app' (must be a single directory name under app/)" >&2
		return 1
		;;
	esac

	if [[ ! -f "$root/app/$app/pubspec.yaml" ]]; then
		echo "ERROR: APP='$app' invalid — missing $root/app/$app/pubspec.yaml" >&2
		return 1
	fi

	opt_name="$(app_select_opt_name "$app")"
	overlay_opt="$root/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/opt"

	APP="$app"
	APP_DIR="$root/app/$app"
	APP_OPT_NAME="$opt_name"
	OVERLAY_OPT_ROOT="$overlay_opt"
	OVERLAY_APP="$overlay_opt/$opt_name"
	DEVICE_APP="/opt/$opt_name"
	APP_FIRMWARE_DIR="$root/output/firmware/$app"
	APP_ROOTFS_IMG="$APP_FIRMWARE_DIR/rootfs.img"
	if app_select_is_hmi "$app"; then
		APP_IS_HMI=1
	else
		APP_IS_HMI=0
	fi
	APP_IS_PRODUCT_HMI="$APP_IS_HMI"

	export APP APP_DIR APP_OPT_NAME OVERLAY_OPT_ROOT OVERLAY_APP DEVICE_APP \
		APP_FIRMWARE_DIR APP_ROOTFS_IMG APP_IS_HMI APP_IS_PRODUCT_HMI
}

# True if app/factory_test is a valid Flutter project (auto-include for rootfs).
app_select_factory_test_exists() {
	local root="${ROOT:-}"
	[[ -n "$root" && -f "$root/app/factory_test/pubspec.yaml" ]]
}

# Overlay path for a given APP id (does not mutate global APP_*).
app_select_overlay_for() {
	local root="${ROOT:-}"
	local app="$1"
	local opt_name
	[[ -n "$root" && -n "$app" ]] || return 1
	opt_name="$(app_select_opt_name "$app")"
	printf '%s\n' "$root/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/opt/$opt_name"
}

# True when overlay tree has a release libapp.so.
app_select_overlay_has_release() {
	local dest="$1"
	[[ -f "$dest/lib/libapp.so" ]]
}
