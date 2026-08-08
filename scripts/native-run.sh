#!/usr/bin/env bash
# Run SDK build commands on the Linux host (Ubuntu x64). macOS uses docker-run.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="$ROOT/linux-sdk"

if [[ ! -d "$SDK" ]]; then
  echo "ERROR: SDK not found at $SDK" >&2
  exit 1
fi

if [[ -z "${BUILD_JOBS:-}" ]]; then
  BUILD_JOBS=8
fi
export BUILD_JOBS

# shellcheck source=scripts/build-env.sh
source "$ROOT/scripts/build-env.sh"
setup_build_env

export LWS_HMI_ROOT="$ROOT"
export LWS_HMI_SDK_DIR="$SDK"

if [[ -d "${CCACHE_DIR:-}" ]] || command -v ccache >/dev/null 2>&1; then
  export CCACHE_DIR="${CCACHE_DIR:-$ROOT/.cache/ccache}"
  mkdir -p "$CCACHE_DIR"
fi

cd "$SDK"

if [[ $# -eq 0 ]]; then
  exec bash -l
fi
exec "$@"
