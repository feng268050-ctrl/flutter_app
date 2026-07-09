#!/usr/bin/env bash
# Upload local flutter-engine tarball to LWS_HMI_CACHE_ROOT (team NAS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=scripts/cache-mirror.sh
source "$ROOT/scripts/cache-mirror.sh"
cache_mirror_load_env "$ROOT"

VERSION="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "3.24.4")"
TARBALL="$ROOT/.cache/flutter-engine/flutter-${VERSION}.tar.gz"
TARBALL_NAME="$(basename "$TARBALL")"

if [[ ! -f "$TARBALL" ]]; then
  echo "ERROR: tarball missing: $TARBALL" >&2
  echo "  Run: make fetch-flutter-engine" >&2
  exit 1
fi

if [[ -z "${LWS_HMI_CACHE_ROOT:-}" ]]; then
  echo "ERROR: set LWS_HMI_CACHE_ROOT in .env (NAS mount path)" >&2
  exit 1
fi

LWS_HMI_CACHE_PUBLISH=1 cache_mirror_publish flutter-engine "$VERSION" "$TARBALL_NAME" "$TARBALL"
echo "cache-publish-flutter-engine: done"
