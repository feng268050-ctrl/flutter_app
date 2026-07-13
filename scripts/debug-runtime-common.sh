#!/usr/bin/env bash
# Debug engine/runtime manifest helpers (same Flutter version, debug runtime mode).
set -euo pipefail

# shellcheck source=scripts/prebuilt-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/prebuilt-common.sh"

debug_runtime_root() {
	local self="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
	cd "$(dirname "$self")/.." && pwd
}

debug_runtime_engine_version() {
	local root="$1"
	read_version_file "$root/overlay/buildroot/flutter-engine.version" "3.24.4"
}

debug_runtime_mode_dir() {
	local root="$1"
	local version="${2:-$(debug_runtime_engine_version "$root")}"
	echo "$root/prebuilt/flutter-engine/${version}/arm64-debug"
}

debug_runtime_staging_dir() {
	local root="$1"
	echo "$root/.cache/debug-app-staging"
}

debug_runtime_host_engine() {
	local root="$1"
	local dir
	dir="$(debug_runtime_mode_dir "$root")"
	if [[ -f "$dir/target/usr/lib/libflutter_engine.so" ]]; then
		echo "$dir/target/usr/lib/libflutter_engine.so"
		return 0
	fi
	if [[ -f "$dir/libflutter_engine.so" ]]; then
		echo "$dir/libflutter_engine.so"
		return 0
	fi
	return 1
}

debug_runtime_host_icu() {
	local root="$1"
	local dir version
	version="$(debug_runtime_engine_version "$root")"
	dir="$(debug_runtime_mode_dir "$root")"
	if [[ -f "$dir/target/usr/share/flutter/debug/data/icudtl.dat" ]]; then
		echo "$dir/target/usr/share/flutter/debug/data/icudtl.dat"
		return 0
	fi
	if [[ -f "$dir/icudtl.dat" ]]; then
		echo "$dir/icudtl.dat"
		return 0
	fi
	return 1
}

debug_runtime_file_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		echo "ERROR: sha256sum or shasum required for debug runtime manifest" >&2
		return 1
	fi
}

debug_runtime_write_manifest() {
	local dest_dir="$1" engine_path="$2" icu_path="$3" version="$4"
	local engine_sha icu_sha
	engine_sha="$(debug_runtime_file_sha256 "$engine_path")"
	icu_sha="$(debug_runtime_file_sha256 "$icu_path")"
	mkdir -p "$dest_dir"
	cat >"$dest_dir/manifest.json" <<EOF
{
  "engine_version": "${version}",
  "runtime_mode": "debug",
  "files": {
    "libflutter_engine.so": "${engine_sha}",
    "icudtl.dat": "${icu_sha}"
  }
}
EOF
	cp -f "$engine_path" "$dest_dir/libflutter_engine.so"
	cp -f "$icu_path" "$dest_dir/icudtl.dat"
}

debug_runtime_resolve_host_paths() {
	local root="$1"
	local engine icu bundle_engine bundle_icu version
	version="$(debug_runtime_engine_version "$root")"

	if engine="$(debug_runtime_host_engine "$root" 2>/dev/null)" && icu="$(debug_runtime_host_icu "$root" 2>/dev/null)"; then
		echo "$engine"
		echo "$icu"
		return 0
	fi

	bundle_engine="$root/.cache/debug-app-staging/debug-runtime/${version}/libflutter_engine.so"
	bundle_icu="$root/.cache/debug-app-staging/debug-runtime/${version}/icudtl.dat"
	if [[ -f "$bundle_engine" && -f "$bundle_icu" ]]; then
		echo "$bundle_engine"
		echo "$bundle_icu"
		return 0
	fi

	cat >&2 <<EOF
ERROR: debug engine/ICU not found for Flutter ${version}.

Build the matching arm64-debug prebuilt:
  FLUTTER_ENGINE_RUNTIME_MODE=debug make build-flutter-engine

Or run a debug app build first (uses flutterpi_tool cache):
  make build-debug-app
EOF
	return 1
}

debug_runtime_prereq_hint() {
	local root="$1"
	local version
	version="$(debug_runtime_engine_version "$root")"
	echo "FLUTTER_ENGINE_RUNTIME_MODE=debug make build-flutter-engine"
}
