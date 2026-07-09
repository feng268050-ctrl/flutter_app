#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != Darwin ]]; then
  exec bash "$ROOT/scripts/native-run.sh" "$@"
fi

IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
SDK="$ROOT/sdk"
VOLUME="${LWS_HMI_DOCKER_VOLUME:-lws-hmi-sdk}"

if [[ -z "${BUILD_JOBS:-}" ]]; then
  BUILD_JOBS=4
fi

USE_VOLUME=0
if [[ "${BUILD_BIND_MOUNT:-}" != "1" ]]; then
  USE_VOLUME=1
fi

if [[ ! -d "$SDK" && "$USE_VOLUME" != "1" ]]; then
  echo "ERROR: $SDK missing. Run: make setup" >&2
  exit 1
fi

if [[ "$USE_VOLUME" == "1" ]]; then
  bash "$ROOT/scripts/docker-volume.sh" ensure-ready
  docker run --rm --platform "$PLATFORM" \
    -v "$ROOT:/work/lws-hmi" \
    -v "$VOLUME:/work/sdk" \
    -e LWS_HMI_DOCKER=1 \
    -e LWS_HMI_SDK_DIR=/work/sdk \
    -w /work/lws-hmi \
    "$IMAGE" \
    bash /work/lws-hmi/scripts/apply-overlay.sh
fi

docker_args=(
  run
  --rm
  --platform "$PLATFORM"
  --privileged
  --shm-size=2g
  --ulimit "nofile=65536:65536"
  -e LWS_HMI_DOCKER=1
  -e "BUILD_JOBS=${BUILD_JOBS}"
  -e LWS_HMI_ROOT=/work/lws-hmi
  -e LWS_HMI_SDK_DIR=/work/sdk
  -v "$ROOT:/work/lws-hmi"
  -v lws-hmi-ccache:/ccache
  -e CCACHE_DIR=/ccache
  -w /work/sdk
)

if [[ "$USE_VOLUME" == "1" ]]; then
  docker_args+=(-v "${VOLUME}:/work/sdk")
else
  docker_args+=(-v "$SDK:/work/sdk")
fi

if [[ -t 0 ]]; then
  docker_args+=(-it)
else
  docker_args+=(-i)
fi

if [[ $# -eq 0 ]]; then
  docker "${docker_args[@]}" "$IMAGE"
else
  docker "${docker_args[@]}" "$IMAGE" "$@"
fi
