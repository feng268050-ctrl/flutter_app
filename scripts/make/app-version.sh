#!/usr/bin/env bash
# Read or bump app versionName + versionCode in app/build.gradle.kts.
# Combined display: versionName+versionCode (e.g. 1.0.27+1027).
# versionCode = major*1000 + minor*100 + patch (OTA / device compare uses this integer).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GRADLE_FILE="${ROOT}/app/build.gradle.kts"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

read_version_name() {
  local name
  name="$(sed -n 's/^[[:space:]]*versionName[[:space:]]*=[[:space:]]*"\([^"]*\)"/\1/p' "$GRADLE_FILE" | sed -n '1p')"
  [[ -n "$name" ]] || die "failed to parse versionName from $GRADLE_FILE"
  printf '%s' "$name"
}

read_version_code() {
  local code
  code="$(sed -n 's/^[[:space:]]*versionCode[[:space:]]*=[[:space:]]*\([0-9][0-9]*\)/\1/p' "$GRADLE_FILE" | sed -n '1p')"
  [[ -n "$code" ]] || die "failed to parse versionCode from $GRADLE_FILE (expected integer literal)"
  printf '%s' "$code"
}

print_combined() {
  printf '%s+%s\n' "$(read_version_name)" "$(read_version_code)"
}

# Encode x.y.z -> Mmmpp (e.g. 1.0.27 -> 1027).
encode_version_code() {
  local major="$1" minor="$2" patch="$3"
  printf '%d' $(( major * 1000 + minor * 100 + patch ))
}

parse_semver_triplet() {
  local name="$1"
  if [[ ! "$name" =~ ^([0-9])\.([0-9])\.([0-9]{1,3})$ ]]; then
    die "invalid version name: expected x.y.z (major/minor one digit, patch 0-100)"
  fi
  local patch="${BASH_REMATCH[3]}"
  patch="$((10#$patch))"
  if (( patch > 100 )); then
    die "invalid version name: patch must be 0-100 (got $patch)"
  fi
  PARSED_MAJOR="${BASH_REMATCH[1]}"
  PARSED_MINOR="${BASH_REMATCH[2]}"
  PARSED_PATCH="$patch"
}

resolve_bump_args() {
  local version="$1"
  [[ -n "$version" ]] || die "VERSION is required (e.g. VERSION=1.0.27 or VERSION=1.0.27+1027)"

  local name build
  if [[ "$version" == *+* ]]; then
    name="${version%+*}"
    build="${version#*+}"
    [[ "$build" =~ ^[1-9][0-9]*$ ]] || die "invalid VERSION: build must be a positive integer"
  else
    name="$version"
    build=""
  fi

  parse_semver_triplet "$name"
  local expected
  expected="$(encode_version_code "$PARSED_MAJOR" "$PARSED_MINOR" "$PARSED_PATCH")"

  if [[ -z "$build" ]]; then
    build="$expected"
  elif [[ "$build" != "$expected" ]]; then
    die "invalid VERSION: +${build} does not match encoded versionCode ${expected} for ${name} (use VERSION=${name} or VERSION=${name}+${expected})"
  fi

  RESOLVED_NAME="$name"
  RESOLVED_BUILD="$build"
}

bump_version() {
  resolve_bump_args "$1"

  [[ -f "$GRADLE_FILE" ]] || die "missing $GRADLE_FILE"

  if [[ "$(uname -s)" == Darwin ]]; then
    sed -i '' \
      -e "s/^[[:space:]]*versionName[[:space:]]*=.*/        versionName = \"${RESOLVED_NAME}\"/" \
      -e "s/^[[:space:]]*versionCode[[:space:]]*=.*/        versionCode = ${RESOLVED_BUILD}/" \
      "$GRADLE_FILE"
  else
    sed -i \
      -e "s/^[[:space:]]*versionName[[:space:]]*=.*/        versionName = \"${RESOLVED_NAME}\"/" \
      -e "s/^[[:space:]]*versionCode[[:space:]]*=.*/        versionCode = ${RESOLVED_BUILD}/" \
      "$GRADLE_FILE"
  fi

  local after expected
  expected="${RESOLVED_NAME}+${RESOLVED_BUILD}"
  after="$(print_combined)"
  if [[ "$after" != "$expected" ]]; then
    die "post-bump verification failed (expected ${expected}, got ${after})"
  fi
  printf '%s\n' "$after"
}

usage() {
  cat >&2 <<'EOF'
Usage:
  app-version.sh print
  app-version.sh bump <x.y.z> | <x.y.z+code>

versionCode is encoded as major*1000 + minor*100 + patch (1.0.27 -> 1027).
If +code is omitted, it is computed automatically.
EOF
  exit 1
}

main() {
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
