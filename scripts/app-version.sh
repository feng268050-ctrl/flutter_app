#!/usr/bin/env bash
# Read or bump Flutter app version in app/<APP>/pubspec.yaml (and optional app_version.dart).
# Combined display: versionName+buildNumber (e.g. 1.0.40+10040).
# Build = major*10000 + minor*100 + patch (major 0–9, minor 0–99, patch 0–99).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

pubspec_path() {
	printf '%s\n' "${APP_DIR}/pubspec.yaml"
}

dart_version_path() {
	printf '%s\n' "${APP_DIR}/lib/app_version.dart"
}

# Read combined version: name+build from pubspec `version:` line.
read_combined() {
	local pubspec line name_build
	pubspec="$(pubspec_path)"
	[[ -f "$pubspec" ]] || die "missing $pubspec"
	line="$(sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$pubspec" | sed -n '1p')"
	[[ -n "$line" ]] || die "failed to parse version: from $pubspec"
	name_build="$line"
	if [[ "$name_build" != *+* ]]; then
		die "unparsable version in $pubspec (expected name+build, got '$name_build')"
	fi
	printf '%s\n' "$name_build"
}

print_combined() {
	read_combined
}

# Encode x.y.z -> major*10000 + minor*100 + patch (e.g. 1.0.40 -> 10040).
encode_build() {
	local major="$1" minor="$2" patch="$3"
	printf '%d' $((major * 10000 + minor * 100 + patch))
}

# Parse name into PARSED_MAJOR / PARSED_MINOR / PARSED_PATCH; fail on overflow.
parse_semver_triplet() {
	local name="$1"
	if [[ ! "$name" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
		die "invalid version name: expected x.y.z (got '$name')"
	fi
	local major minor patch
	major="$((10#${BASH_REMATCH[1]}))"
	minor="$((10#${BASH_REMATCH[2]}))"
	patch="$((10#${BASH_REMATCH[3]}))"

	# Digit-budget check after numeric parse (1.00.40 OK; 1.100.0 / 10.0.0 / 1.0.100 fail).
	if ((major > 9)); then
		die "invalid version name: major exceeds 9 (got $major)"
	fi
	if ((minor > 99)); then
		die "invalid version name: minor exceeds 99 (got $minor)"
	fi
	if ((patch > 99)); then
		die "invalid version name: patch exceeds 99 (got $patch)"
	fi

	# Canonical display name without leading zeros on components.
	PARSED_MAJOR="$major"
	PARSED_MINOR="$minor"
	PARSED_PATCH="$patch"
	PARSED_NAME="${major}.${minor}.${patch}"
}

resolve_bump_args() {
	local version="$1"
	[[ -n "$version" ]] || die "VERSION is required (e.g. VERSION=1.0.40 or VERSION=1.0.40+10040)"

	local name build
	if [[ "$version" == *+* ]]; then
		name="${version%%+*}"
		build="${version#*+}"
		[[ "$build" =~ ^[0-9]+$ ]] || die "invalid VERSION: build must be a non-negative integer"
		# Reject extra '+' segments.
		if [[ "$version" == *+*+* ]]; then
			die "invalid VERSION: expected x.y.z or x.y.z+build (got '$version')"
		fi
	else
		name="$version"
		build=""
	fi

	parse_semver_triplet "$name"
	local expected
	expected="$(encode_build "$PARSED_MAJOR" "$PARSED_MINOR" "$PARSED_PATCH")"

	if [[ -z "$build" ]]; then
		build="$expected"
	else
		# Compare numerically so leading zeros on explicit build still match.
		if ((10#$build != expected)); then
			die "invalid VERSION: +${build} does not match encoded build ${expected} for ${PARSED_NAME} (use VERSION=${PARSED_NAME} or VERSION=${PARSED_NAME}+${expected})"
		fi
		build="$expected"
	fi

	RESOLVED_NAME="$PARSED_NAME"
	RESOLVED_BUILD="$build"
}

sed_inplace() {
	# Portable in-place sed: Darwin needs sed -i '', GNU accepts sed -i.
	if [[ "$(uname -s)" == Darwin ]]; then
		sed -i '' "$@"
	else
		sed -i "$@"
	fi
}

write_pubspec_version() {
	local pubspec name build
	pubspec="$(pubspec_path)"
	name="$1"
	build="$2"
	[[ -f "$pubspec" ]] || die "missing $pubspec"
	sed_inplace -e "s/^[[:space:]]*version:[[:space:]]*.*/version: ${name}+${build}/" "$pubspec"
}

write_dart_version() {
	local dart name build
	dart="$(dart_version_path)"
	[[ -f "$dart" ]] || return 0
	name="$1"
	build="$2"
	sed_inplace \
		-e "s/^const String kSystemVersion = '.*';/const String kSystemVersion = '${name}';/" \
		-e "s/^const int kSystemVersionCode = [0-9][0-9]*;/const int kSystemVersionCode = ${build};/" \
		"$dart"
}

bump_version() {
	resolve_bump_args "$1"

	write_pubspec_version "$RESOLVED_NAME" "$RESOLVED_BUILD"
	write_dart_version "$RESOLVED_NAME" "$RESOLVED_BUILD"

	local after expected
	expected="${RESOLVED_NAME}+${RESOLVED_BUILD}"
	after="$(read_combined)"
	if [[ "$after" != "$expected" ]]; then
		die "post-bump verification failed (expected ${expected}, got ${after})"
	fi
	printf '%s\n' "$after"
}

usage() {
	cat >&2 <<'EOF'
Usage:
  app-version.sh print
  app-version.sh bump <x.y.z> | <x.y.z+build>

APP= selects app/<APP> (default lws_hmi) via app-select.sh.
Build is encoded as major*10000 + minor*100 + patch (1.0.40 -> 10040).
Ranges: major 0–9, minor 0–99, patch 0–99.
If +build is omitted, it is computed automatically.
When app/<APP>/lib/app_version.dart exists, bump also syncs kSystemVersion / kSystemVersionCode.
EOF
	exit 1
}

main() {
	app_select_resolve || exit 1

	local cmd="${1:-}"
	shift || true
	case "$cmd" in
	print)
		print_combined
		;;
	bump)
		[[ $# -eq 1 ]] || usage
		bump_version "$1"
		;;
	*)
		usage
		;;
	esac
}

main "$@"
