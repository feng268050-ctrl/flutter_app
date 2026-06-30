#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${DOCKER_IMAGE:-lws-hmi-builder:22.04}"
PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker Desktop." >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running." >&2
    exit 1
  fi
}

require_docker

if docker image inspect "$IMAGE" >/dev/null 2>&1 && [[ "${REBUILD_IMAGE:-}" != "1" ]]; then
  echo "Using existing image $IMAGE (set REBUILD_IMAGE=1 to rebuild)"
  exit 0
fi

echo "Building $IMAGE ($PLATFORM) ..."
docker build \
  --platform "$PLATFORM" \
  -t "$IMAGE" \
  -f "$ROOT/docker/Dockerfile" \
  "$ROOT"
