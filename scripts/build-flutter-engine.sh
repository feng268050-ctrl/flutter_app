#!/usr/bin/env bash
# Download flutter-engine source tarball into .cache/ (gclient via depot_tools).
# Skipped when prebuilt/flutter-engine/ is present (clone + build-rootfs uses prebuilt).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
SDK="$(bash "$ROOT/scripts/link-sdk.sh" --print)"
ENGINE_PKG="$SDK/buildroot/package/flutter-engine"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-engine.version"

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

RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"
ENGINE_PREBUILT="$ROOT/prebuilt/flutter-engine/${VERSION}/arm64-${RUNTIME_MODE}"
FORCE="${FORCE:-0}"

if prebuilt_ready "$ENGINE_PREBUILT" && [[ "$FORCE" != "1" ]]; then
  echo "flutter-engine $VERSION: prebuilt ready at $ENGINE_PREBUILT (skipping gclient fetch)"
  exit 0
fi

CACHE_DIR="$ROOT/.cache/flutter-engine"
TARBALL="$CACHE_DIR/flutter-${VERSION}.tar.gz"
DEPOT="$ROOT/.cache/depot_tools"
SCRATCH="$ROOT/.cache/flutter-engine/scratch"
JOBS="${BUILD_JOBS:-8}"

if [[ ! -x "$ENGINE_PKG/gen-tarball" ]]; then
  echo "ERROR: $ENGINE_PKG/gen-tarball not found (check LINUX_SDK / make link-sdk)" >&2
  exit 1
fi

ensure_depot_tools() {
  if [[ -f "$DEPOT/gclient.py" ]]; then
    return 0
  fi
  echo "Cloning depot_tools into $DEPOT ..."
  mkdir -p "$(dirname "$DEPOT")"
  git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT"
}

if [[ "$FORCE" == "1" ]]; then
  rm -f "$TARBALL"
  rm -rf "$SCRATCH"
fi

if [[ -f "$TARBALL" ]]; then
  echo "flutter-engine $VERSION: using existing $TARBALL"
  exit 0
fi

mkdir -p "$CACHE_DIR"
ensure_depot_tools

export PATH="$DEPOT:${PATH}"
export TAR="${TAR:-tar}"

echo "flutter-engine $VERSION: downloading via gclient (this can take a long time) ..."
echo "  Tip: after one make build-rootfs, run make build-prebuilt and commit prebuilt/."
"$ENGINE_PKG/gen-tarball" \
  --dot-gclient "$ENGINE_PKG/dot-gclient" \
  --jobs "$JOBS" \
  --scratch-dir "$SCRATCH" \
  --tarball-dl-path "$TARBALL" \
  --version "$VERSION"

echo "Saved: $TARBALL"
du -sh "$TARBALL"
