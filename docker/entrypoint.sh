#!/usr/bin/env bash
set -euo pipefail

export DOCKER=1

ROOT="${DOCKER_ROOT:-/work/lws-hmi}"
if [[ -f "$ROOT/scripts/build-env.sh" ]]; then
  # shellcheck source=scripts/build-env.sh
  source "$ROOT/scripts/build-env.sh"
  setup_build_env
else
  BUILD_JOBS="${BUILD_JOBS:-8}"
  export BUILD_JOBS
  # Do not set MAKEFLAGS in Docker — see scripts/build-env.sh
  if [[ "${DOCKER:-}" != "1" ]]; then
    export MAKEFLAGS="-j${BUILD_JOBS} ${MAKEFLAGS:-}"
  fi
fi

if [[ -d /work/sdk ]]; then
  cd /work/sdk
fi

if [[ $# -eq 0 ]]; then
  exec bash -l
fi
exec "$@"
