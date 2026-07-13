#!/usr/bin/env bash
# Download flutter-engine source tarball → .cache/flutter-engine/flutter-<ver>.tar.gz
# Order: local cache → NAS/HTTP mirror (LWS_HMI_CACHE_*) → gclient (Docker on macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=scripts/cache-mirror.sh
source "$ROOT/scripts/cache-mirror.sh"
cache_mirror_load_env "$ROOT"

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
ENGINE_PKG="$SDK/buildroot/package/flutter-engine"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-engine.version"
FORCE="${FORCE:-0}"
JOBS="${BUILD_JOBS:-8}"

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

CACHE_DIR="$ROOT/.cache/flutter-engine"
TARBALL="$CACHE_DIR/flutter-${VERSION}.tar.gz"
TARBALL_NAME="$(basename "$TARBALL")"
SCRATCH="$CACHE_DIR/scratch"
DEPOT="$ROOT/.cache/depot_tools"
CATEGORY="flutter-engine"

if [[ -f "$TARBALL" && "$FORCE" != "1" ]]; then
  echo "fetch-flutter-engine $VERSION: using cached $TARBALL"
  exit 0
fi

# gclient needs Linux + GNU getopt; mirror fetch can run on the macOS host first.
if [[ ! -f "$TARBALL" && "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  if cache_mirror_enabled; then
    cache_mirror_fetch "$CATEGORY" "$VERSION" "$TARBALL_NAME" "$TARBALL" || true
  fi
  if [[ -f "$TARBALL" ]]; then
    du -sh "$TARBALL"
    exit 0
  fi
  exec bash "$ROOT/scripts/docker-run.sh" \
    env LWS_HMI_DOCKER=1 \
         FORCE="${FORCE}" \
         FLUTTER_ENGINE_VERSION="${FLUTTER_ENGINE_VERSION:-}" \
         BUILD_JOBS="${BUILD_JOBS:-}" \
         LWS_HMI_CACHE_ROOT="${LWS_HMI_CACHE_ROOT:-}" \
         LWS_HMI_CACHE_URL="${LWS_HMI_CACHE_URL:-}" \
         LWS_HMI_CACHE_PUBLISH="${LWS_HMI_CACHE_PUBLISH:-1}" \
    bash /work/lws-hmi/scripts/fetch-flutter-engine.sh
fi

if [[ "$FORCE" == "1" ]]; then
  rm -f "$TARBALL"
  rm -rf "$SCRATCH"
fi

mkdir -p "$CACHE_DIR"

if [[ ! -f "$TARBALL" ]] && cache_mirror_enabled; then
  cache_mirror_fetch "$CATEGORY" "$VERSION" "$TARBALL_NAME" "$TARBALL" || true
fi

read_depot_tools_version() {
  local mk="$SDK/buildroot/package/depot-tools/depot-tools.mk"
  if [[ -f "$mk" ]]; then
    grep -E '^DEPOT_TOOLS_VERSION[[:space:]]*=' "$mk" | awk '{print $3}'
    return 0
  fi
  echo "1b58dc68659445b1d97d8341f8158be25eab4957"
}

DEPOT_TOOLS_VERSION="$(read_depot_tools_version)"

ensure_depot_tools_python_deps() {
  if python3 -c "import httplib2.socks" 2>/dev/null; then
    return 0
  fi
  echo "fetch-flutter-engine: installing depot_tools Python deps (httplib2==0.22.0) ..."
  python3 -m pip install -q httplib2==0.22.0 pyparsing six
}

ensure_depot_tools() {
  ensure_depot_tools_python_deps
  if [[ -f "$DEPOT/gclient.py" ]]; then
    local current
    current="$(git -C "$DEPOT" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$current" == "$DEPOT_TOOLS_VERSION" ]]; then
      return 0
    fi
    echo "depot_tools: checkout $DEPOT_TOOLS_VERSION (was ${current:-unknown}) ..."
    git -C "$DEPOT" fetch --depth 1 origin "$DEPOT_TOOLS_VERSION"
    git -C "$DEPOT" checkout "$DEPOT_TOOLS_VERSION"
    return 0
  fi
  echo "depot_tools: clone $DEPOT_TOOLS_VERSION → $DEPOT"
  mkdir -p "$(dirname "$DEPOT")"
  git clone --filter=blob:none --no-checkout \
    https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT"
  git -C "$DEPOT" checkout "$DEPOT_TOOLS_VERSION"
}

if [[ ! -f "$TARBALL" ]]; then
  if [[ ! -f "$ENGINE_PKG/dot-gclient" ]]; then
    echo "ERROR: $ENGINE_PKG/dot-gclient not found (check repo-root linux-sdk/)" >&2
    exit 1
  fi
  ensure_depot_tools
  export PATH="$DEPOT:${PATH}"
  echo "fetch-flutter-engine $VERSION: downloading via gclient (long) ..."
  bash "$ROOT/scripts/fetch-flutter-engine-tarball.sh" \
    "$ENGINE_PKG/dot-gclient" \
    "$JOBS" \
    "$SCRATCH" \
    "$TARBALL" \
    "$VERSION"
fi

cache_mirror_publish "$CATEGORY" "$VERSION" "$TARBALL_NAME" "$TARBALL" || true

du -sh "$TARBALL"
echo "fetch-flutter-engine $VERSION: ready at $TARBALL"
echo "  Next: make build-flutter-engine"
