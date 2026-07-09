#!/usr/bin/env bash
# Download flutter-engine sources and pack .cache/flutter-engine/flutter-<ver>.tar.gz
# (replaces SDK gen-tarball with resume + retry; gen-tarball always wipes scratch).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/build-env.sh
source "$ROOT/scripts/build-env.sh"
setup_build_env

DOT_GCLIENT="${1:?dot-gclient path}"
JOBS="${2:?jobs}"
SCRATCH="${3:?scratch dir}"
TARBALL="${4:?tarball path}"
VERSION="${5:?engine version}"

DL_DIR="$(dirname "$TARBALL")"
TARBALL_NAME="$(basename "$TARBALL")"

message() {
  printf '>>> flutter-engine %s %s\n' "$VERSION" "$1"
}

run_gclient_sync() {
  local resume="${1:-0}"
  local attempt max_attempts="${GCLIENT_RETRIES:-5}"

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if [[ "$attempt" -gt 1 ]]; then
      message "gclient retry ${attempt}/${max_attempts} ..."
      sleep $((attempt * 10))
    fi

    if [[ "$resume" == "1" ]]; then
      if gclient.py sync --no-history --shallow -j"${JOBS}"; then
        return 0
      fi
    elif gclient.py sync \
      --delete_unversioned_trees \
      --no-history \
      --reset \
      --shallow \
      -j"${JOBS}"; then
      return 0
    fi
  done

  echo "ERROR: gclient sync failed after ${max_attempts} attempts" >&2
  echo "Hint: check network/proxy access to chrome-infra-packages.appspot.com (cipd)" >&2
  return 1
}

if [[ -f "$TARBALL" ]]; then
  echo "flutter-engine $VERSION: using cached $TARBALL"
  exit 0
fi

mkdir -p "$DL_DIR"

resume=0
if [[ -f "$SCRATCH/.gclient" && -d "$SCRATCH/src/flutter" ]]; then
  resume=1
  message "Resuming gclient sync in $SCRATCH"
else
  rm -rf "$SCRATCH"
  mkdir -p "$SCRATCH"
  message "Downloading"
fi

(
  cd "$SCRATCH"
  if [[ "$resume" != "1" ]]; then
    sed "s%!FLUTTER_VERSION!%${VERSION}%g" "$DOT_GCLIENT" >.gclient
  fi
  run_gclient_sync "$resume"
)

message "Generating tarball"
export TAR="${TAR:-tar}"
(
  cd "$SCRATCH"
  ${TAR} -C src -czf "$TARBALL_NAME" .
)
mv -f "$SCRATCH/$TARBALL_NAME" "$TARBALL"
rm -rf "$SCRATCH"
