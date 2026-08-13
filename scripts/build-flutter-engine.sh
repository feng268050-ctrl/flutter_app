#!/usr/bin/env bash
# Compile flutter-engine via Buildroot and export → prebuilt/flutter-engine/
# Requires: make fetch-flutter-engine (source tarball in .cache/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-engine.version"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${FLUTTER_ENGINE_VERSION:-}" ]]; then
    echo "$FLUTTER_ENGINE_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" ""
}

VERSION="$(read_version)"
if [[ -z "$VERSION" ]]; then
  grep -E '^FLUTTER_ENGINE_VERSION[[:space:]]*=' \
    "$ROOT/overlay/buildroot/package/flutter-engine/flutter-engine.mk" \
    | awk '{print $3}'
fi

ENGINE_PREBUILT="$ROOT/prebuilt/flutter-engine/${VERSION}/arm64-${RUNTIME_MODE}"
TARBALL="$ROOT/.cache/flutter-engine/flutter-${VERSION}.tar.gz"

if prebuilt_ready "$ENGINE_PREBUILT" && [[ "$FORCE" != "1" ]]; then
  echo "flutter-engine $VERSION: prebuilt ready at $ENGINE_PREBUILT"
  exit 0
fi

if [[ "$(uname -s)" == Darwin && "${DOCKER:-}" != "1" ]]; then
  bash "$ROOT/scripts/fetch-flutter-sdk.sh"
  exec bash "$ROOT/scripts/docker-run.sh" \
    env DOCKER=1 \
         FORCE="${FORCE}" \
         FLUTTER_ENGINE_RUNTIME_MODE="${RUNTIME_MODE}" \
         FLUTTER_ENGINE_VERSION="${FLUTTER_ENGINE_VERSION:-}" \
         BUILD_JOBS="${BUILD_JOBS:-}" \
    bash /work/lws-hmi/scripts/build-flutter-engine.sh
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ENGINE_PREBUILT"
fi

if [[ ! -f "$TARBALL" ]]; then
  cat >&2 <<EOF
ERROR: flutter-engine source tarball missing:
  $TARBALL

Download first:
  make fetch-flutter-engine

Or from team NAS cache (set NAS_CACHE_ROOT in .env).
EOF
  exit 1
fi

echo "flutter-engine $VERSION: using tarball $TARBALL"

echo "flutter-engine $VERSION: host Flutter SDK (for gen_snapshot build) ..."
bash "$ROOT/scripts/fetch-flutter-sdk.sh"

echo "flutter-engine $VERSION: compiling in Buildroot (runtime_mode=$RUNTIME_MODE) ..."
export FLUTTER_ENGINE_RUNTIME_MODE="$RUNTIME_MODE"
bash "$ROOT/scripts/br-compile-flutter.sh" flutter-engine

PACK_PI=0 PACK_FLUTTER_SDK=0 \
  FLUTTER_ENGINE_RUNTIME_MODE="$RUNTIME_MODE" \
  bash "$ROOT/scripts/build-prebuilt.sh"

echo "flutter-engine $VERSION: prebuilt at $ENGINE_PREBUILT"
