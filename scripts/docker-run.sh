#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

if [[ "$(uname -s)" != Darwin ]]; then
  exec bash "$ROOT/scripts/native-run.sh" "$@"
fi

IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
SDK="$ROOT/linux-sdk"
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
  if [[ "${LWS_HMI_SKIP_OVERLAY:-}" != "1" ]]; then
    docker run --rm --platform "$PLATFORM" \
      -v "$ROOT:/work/lws-hmi" \
      -v "$VOLUME:/work/sdk" \
      -e LWS_HMI_DOCKER=1 \
      -e LWS_HMI_SDK_DIR=/work/sdk \
      -e "LWS_HMI_WESTON=${LWS_HMI_WESTON:-1}" \
      -w /work/lws-hmi \
      "$IMAGE" \
      bash /work/lws-hmi/scripts/apply-overlay.sh
  fi
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
  -e "LWS_HMI_NO_MAKEFLAGS=${LWS_HMI_NO_MAKEFLAGS:-}"
  -e LWS_HMI_ROOT=/work/lws-hmi
  -e LWS_HMI_SDK_DIR=/work/sdk
  -e "LWS_HMI_WESTON=${LWS_HMI_WESTON:-1}"
  -e "LWS_HMI_CACHE_PUBLISH=${LWS_HMI_CACHE_PUBLISH:-1}"
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

if [[ -n "${LWS_HMI_CACHE_ROOT:-}" && -d "$LWS_HMI_CACHE_ROOT" ]]; then
  docker_args+=(-e "LWS_HMI_CACHE_ROOT=${LWS_HMI_CACHE_ROOT}")
  docker_args+=(-v "${LWS_HMI_CACHE_ROOT}:${LWS_HMI_CACHE_ROOT}")
fi
if [[ -n "${LWS_HMI_CACHE_URL:-}" ]]; then
  docker_args+=(-e "LWS_HMI_CACHE_URL=${LWS_HMI_CACHE_URL}")
fi

FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print 2>/dev/null || true)"
if [[ -n "$FLUTTER_INSTALL" && -d "$FLUTTER_INSTALL" ]]; then
  docker_args+=(-v "$FLUTTER_INSTALL:/work/lws-hmi/flutter-sdk:ro")
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
