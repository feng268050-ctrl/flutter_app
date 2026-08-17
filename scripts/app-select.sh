#!/usr/bin/env bash
# Resolve Make/env APP → Flutter project dir + device install prefix.
# Source from host scripts (requires ROOT). Does not build anything.
#
# Convention:
#   - HMI apps are named with suffix `_hmi` (e.g. lws_hmi, cnc_hmi).
#   - All HMI apps install to /opt/hmi so hmi.service can launch them.
#   - One rootfs has at most one HMI app tree at /opt/hmi (+ optional os_settings).
#   - Non-HMI apps (e.g. os_settings) install to /opt/<APP>.
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

# systemd unit restarted by make push-app for this APP (empty = deploy only).
app_select_push_unit() {
	local app="$1"
	if app_select_is_hmi "$app"; then
		printf '%s\n' hmi.service
	elif [[ "$app" == os_settings ]]; then
		printf '%s\n' os-settings.service
	else
		printf '%s\n' ""
	fi
}

# Usage: app_select_resolve   # reads APP from env; defaults to lws_hmi
# Exports:
#   APP, APP_DIR, APP_OPT_NAME, DEVICE_APP, APP_IS_HMI
#   APP_BUNDLE_RELEASE (app/<APP>/build/bundle/release — make build-app output)
#   APP_PUSH_UNIT (systemd unit for push-app restart; empty if none)
#   APP_FIRMWARE_DIR (output/firmware/<APP>), APP_ROOTFS_IMG
#   APP_PACKAGE_DIR (output/app/<APP> — pack-app / publish-app tar.gz)
#   APP_IS_PRODUCT_HMI — alias of APP_IS_HMI (compat)
app_select_resolve() {
	local root="${ROOT:-}"
	local app opt_name

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

	APP="$app"
	APP_DIR="$root/app/$app"
	APP_OPT_NAME="$opt_name"
	APP_BUNDLE_RELEASE="$root/app/$app/build/bundle/release"
	DEVICE_APP="/opt/$opt_name"
	APP_FIRMWARE_DIR="$root/output/firmware/$app"
	APP_ROOTFS_IMG="$APP_FIRMWARE_DIR/rootfs.img"
	APP_PACKAGE_DIR="$root/output/app/$app"
	if app_select_is_hmi "$app"; then
		APP_IS_HMI=1
	else
		APP_IS_HMI=0
	fi
	APP_IS_PRODUCT_HMI="$APP_IS_HMI"
	APP_PUSH_UNIT="$(app_select_push_unit "$app")"

	export APP APP_DIR APP_OPT_NAME APP_BUNDLE_RELEASE DEVICE_APP \
		APP_FIRMWARE_DIR APP_ROOTFS_IMG APP_PACKAGE_DIR APP_IS_HMI APP_IS_PRODUCT_HMI \
		APP_PUSH_UNIT
}

# True if app/os_settings is a valid Flutter project (auto-include for rootfs).
app_select_os_settings_exists() {
	local root="${ROOT:-}"
	[[ -n "$root" && -f "$root/app/os_settings/pubspec.yaml" ]]
}

# Release bundle tree from make build-app (app/<APP>/build/bundle/release).
app_select_bundle_for() {
	local root="${ROOT:-}"
	local app="$1"
	[[ -n "$root" && -n "$app" ]] || return 1
	printf '%s\n' "$root/app/$app/build/bundle/release"
}

# True when release bundle has lib/libapp.so.
app_select_bundle_has_release() {
	local dest="$1"
	[[ -f "$dest/lib/libapp.so" ]]
}
