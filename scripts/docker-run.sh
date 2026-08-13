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
VOLUME="${DOCKER_VOLUME:-lws-hmi-sdk}"

if [[ -z "${BUILD_JOBS:-}" ]]; then
  BUILD_JOBS=8
fi

USE_VOLUME=0
if [[ "${BUILD_BIND_MOUNT:-}" != "1" ]]; then
  USE_VOLUME=1
fi

if [[ ! -d "$SDK" && "$USE_VOLUME" != "1" ]]; then
  echo "ERROR: $SDK missing. Run: make setup" >&2
  exit 1
fi

# Default: do not auto-apply overlay (explicit make apply-overlay).
# Opt-in before a Docker command: SKIP_OVERLAY=0 bash scripts/docker-run.sh …
SKIP_OVERLAY="${SKIP_OVERLAY:-1}"

if [[ "$USE_VOLUME" == "1" ]]; then
  bash "$ROOT/scripts/docker-volume.sh" ensure-ready
  if [[ "$SKIP_OVERLAY" != "1" ]]; then
    docker run --rm --platform "$PLATFORM" \
      -v "$ROOT:/work/lws-hmi" \
      -v "$VOLUME:/work/sdk" \
      -e DOCKER=1 \
      -e SDK_DIR=/work/sdk \
      -e "FORCE_PLATFORM_OVERLAY=${FORCE_PLATFORM_OVERLAY:-0}" \
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
  -e DOCKER=1
  -e "BUILD_JOBS=${BUILD_JOBS}"
  -e "NO_MAKEFLAGS=${NO_MAKEFLAGS:-}"
  -e DOCKER_ROOT=/work/lws-hmi
  -e SDK_DIR=/work/sdk
  -e "FORCE_PLATFORM_OVERLAY=${FORCE_PLATFORM_OVERLAY:-0}"
  -e "NAS_READ_ONLY=${NAS_READ_ONLY:-0}"
  -e "FORCE=${FORCE:-0}"
  -e "FORCE_KERNEL_IMAGE=${FORCE_KERNEL_IMAGE:-0}"
  -e "OPTEE_OS_VER=${OPTEE_OS_VER:-}"
  -e "TA_SIGN_KEY=${TA_SIGN_KEY:-}"
  -e "SKIP_OVERLAY=${SKIP_OVERLAY}"
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

if [[ -n "${NAS_CACHE_ROOT:-}" && -d "$NAS_CACHE_ROOT" ]]; then
  docker_args+=(-e "NAS_CACHE_ROOT=${NAS_CACHE_ROOT}")
  docker_args+=(-v "${NAS_CACHE_ROOT}:${NAS_CACHE_ROOT}")
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
