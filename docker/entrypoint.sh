#!/usr/bin/env bash
set -euo pipefail

export LWS_HMI_DOCKER=1

ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
if [[ -f "$ROOT/scripts/build-env.sh" ]]; then
  # shellcheck source=scripts/build-env.sh
  source "$ROOT/scripts/build-env.sh"
  setup_build_env
else
  BUILD_JOBS="${BUILD_JOBS:-4}"
  export BUILD_JOBS
  export MAKEFLAGS="-j${BUILD_JOBS} ${MAKEFLAGS:-}"
fi

if [[ -d /work/sdk ]]; then
  cd /work/sdk
fi

if [[ $# -eq 0 ]]; then
  exec bash -l
fi
exec "$@"
