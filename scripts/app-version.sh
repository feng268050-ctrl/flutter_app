#!/usr/bin/env bash
# Print or bump product versions:
#   OS Version  — /etc/os-release VERSION= (Cyber OS; default)
#   Flutter app — app/<APP>/pubspec.yaml (+ optional app_version.dart) when print-app/bump-app
#
# Combined Flutter display: versionName+buildNumber (e.g. 1.0.40+10040).
# Build = major*10000 + minor*100 + patch (major 0–9, minor 0–99, patch 0–99).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"

OS_RELEASE_SOT="${OS_RELEASE_SOT:-$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/etc/os-release}"

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

# Parse KEY= or KEY="..." from os-release into REPLY.
os_release_get() {
	local key="$1" file="${2:-$OS_RELEASE_SOT}" line val
	[[ -f "$file" ]] || die "missing $file"
	line="$(grep -E "^${key}=" "$file" | head -n1 || true)"
	[[ -n "$line" ]] || die "missing ${key}= in $file"
	val="${line#*=}"
	if [[ "$val" == \"*\" ]]; then
		val="${val:1:${#val}-2}"
	fi
	REPLY="$val"
}

read_os_version() {
	# Product OS Version for OTA / Settings is VERSION= (full SemVer).
	os_release_get VERSION
	local line="$REPLY"
	[[ -n "$line" ]] || die "empty VERSION in $OS_RELEASE_SOT"
	if [[ ! "$line" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		die "invalid VERSION in $OS_RELEASE_SOT (expected x.y.z, got '$line')"
	fi
	printf '%s\n' "$line"
}

write_os_version() {
	local name="$1"
	local major minor
	if [[ ! "$name" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
		die "invalid OS Version: expected x.y.z (got '$name')"
	fi
	major="${BASH_REMATCH[1]}"
	minor="${BASH_REMATCH[2]}"
	# VERSION_ID is major.minor (distro series); VERSION is full SemVer.
	mkdir -p "$(dirname "$OS_RELEASE_SOT")"
	cat >"$OS_RELEASE_SOT" <<EOF
NAME="Cyber OS"
ID=cyberos
ID_LIKE="buildroot"
VERSION="${name}"
VERSION_ID=${major}.${minor}
PRETTY_NAME="Cyber OS ${name}"
EOF
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

encode_build() {
	local major="$1" minor="$2" patch="$3"
	printf '%d' $((major * 10000 + minor * 100 + patch))
}

parse_semver_triplet() {
	local name="$1"
	if [[ ! "$name" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
		die "invalid version name: expected x.y.z (got '$name')"
	fi
	local major minor patch
	major="$((10#${BASH_REMATCH[1]}))"
	minor="$((10#${BASH_REMATCH[2]}))"
	patch="$((10#${BASH_REMATCH[3]}))"

	if ((major > 9)); then
		die "invalid version name: major exceeds 9 (got $major)"
	fi
	if ((minor > 99)); then
		die "invalid version name: minor exceeds 99 (got $minor)"
	fi
	if ((patch > 99)); then
		die "invalid version name: patch exceeds 99 (got $patch)"
	fi

	PARSED_MAJOR="$major"
	PARSED_MINOR="$minor"
	PARSED_PATCH="$patch"
	PARSED_NAME="${major}.${minor}.${patch}"
}

resolve_bump_args() {
	local version="$1"
	local allow_build="${2:-1}"
	[[ -n "$version" ]] || die "VERSION is required (e.g. VERSION=1.0.40 or VERSION=1.0.40+10040)"

	local name build
	if [[ "$version" == *+* ]]; then
		[[ "$allow_build" == "1" ]] || die "OS Version bump expects x.y.z (no +build); got '$version'"
		name="${version%%+*}"
		build="${version#*+}"
		[[ "$build" =~ ^[0-9]+$ ]] || die "invalid VERSION: build must be a non-negative integer"
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
		if ((10#$build != expected)); then
			die "invalid VERSION: +${build} does not match encoded build ${expected} for ${PARSED_NAME} (use VERSION=${PARSED_NAME} or VERSION=${PARSED_NAME}+${expected})"
		fi
		build="$expected"
	fi

	RESOLVED_NAME="$PARSED_NAME"
	RESOLVED_BUILD="$build"
}

sed_inplace() {
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
		-e "s/^const String kHmiVersion = '.*';/const String kHmiVersion = '${name}';/" \
		-e "s/^const int kHmiVersionCode = [0-9][0-9]*;/const int kHmiVersionCode = ${build};/" \
		"$dart"
}

bump_os_version() {
	resolve_bump_args "$1" 0
	write_os_version "$RESOLVED_NAME"
	local after
	after="$(read_os_version)"
	if [[ "$after" != "$RESOLVED_NAME" ]]; then
		die "post-bump OS verification failed (expected ${RESOLVED_NAME}, got ${after})"
	fi
	printf '%s\n' "$after"
}

bump_app_version() {
	resolve_bump_args "$1" 1

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
  app-version.sh print-os | print-app
  app-version.sh bump-os <x.y.z>
  app-version.sh bump-app <x.y.z> | <x.y.z+build>

  Legacy (APP set → app; else → OS):
  app-version.sh print
  app-version.sh bump <version>

print-os / bump-os: overlay etc/os-release (Cyber OS; VERSION= SemVer, VERSION_ID=major.minor).
print-app / bump-app: APP= selects app/<APP> (default lws_hmi) via app-select.sh.
Flutter build is major*10000 + minor*100 + patch (1.0.40 -> 10040).
When app/<APP>/lib/app_version.dart exists, bump-app syncs kHmiVersion / kHmiVersionCode.
EOF
	exit 1
}

main() {
	local cmd="${1:-}"
	shift || true
	case "$cmd" in
	print-os)
		read_os_version
		;;
	bump-os)
		[[ $# -eq 1 ]] || usage
		bump_os_version "$1"
		;;
	print-app)
		app_select_resolve || exit 1
		read_combined
		;;
	bump-app)
		[[ $# -eq 1 ]] || usage
		app_select_resolve || exit 1
		bump_app_version "$1"
		;;
	print)
		if [[ -n "${APP:-}" ]]; then
			app_select_resolve || exit 1
			read_combined
		else
			read_os_version
		fi
		;;
	bump)
		[[ $# -eq 1 ]] || usage
		if [[ -n "${APP:-}" ]]; then
			app_select_resolve || exit 1
			bump_app_version "$1"
		else
			bump_os_version "$1"
		fi
		;;
	*)
		usage
		;;
	esac
}

main "$@"
