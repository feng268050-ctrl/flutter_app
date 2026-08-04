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
	read_version_file "$root/overlay/buildroot/flutter-engine.version" "3.41.9"
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
	local engine icu version prebuilt_dir
	version="$(debug_runtime_engine_version "$root")"
	prebuilt_dir="$(debug_runtime_mode_dir "$root")"

	# Only accept the versioned arm64-debug prebuilt. Do NOT fall back to
	# .cache/debug-app-staging or app/.../flutter_assets — those often retain a
	# prior-generation libflutter_engine.so (e.g. 3.24) after a pin bump and
	# then get re-labeled as the new ENGINE_VER, causing:
	#   Dart Error: Can't load Kernel binary: Invalid kernel binary format version.
	if engine="$(debug_runtime_host_engine "$root" 2>/dev/null)" && \
		icu="$(debug_runtime_host_icu "$root" 2>/dev/null)"; then
		echo "$engine"
		echo "$icu"
		return 0
	fi

	cat >&2 <<EOF
ERROR: debug engine/ICU not found for Flutter ${version}.

Expected prebuilt:
  ${prebuilt_dir}/target/usr/lib/libflutter_engine.so
  ${prebuilt_dir}/target/usr/share/flutter/debug/data/icudtl.dat

Build the matching arm64-debug engine (do not reuse release or stale cache):
  FLUTTER_ENGINE_RUNTIME_MODE=debug FORCE=1 make build-flutter-engine

Commit the result under prebuilt/flutter-engine/${version}/arm64-debug/ (same as arm64-release)
so teammates can make debug-app without a multi-hour rebuild.

Then:
  make build-debug-app
  make debug-app
EOF
	return 1
}

debug_runtime_prereq_hint() {
	local root="$1"
	local version
	version="$(debug_runtime_engine_version "$root")"
	echo "FLUTTER_ENGINE_RUNTIME_MODE=debug make build-flutter-engine"
}
