#!/usr/bin/env bash
# Fetch MediaMTX linux/arm64 → prebuilt/ (Phase 4a: official release first, go build fallback).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/third-party/mediamtx.version"
SRC_ROOT="$ROOT/.cache/mediamtx"
REPO_DIR="$SRC_ROOT/src"
OUT_DIR="$ROOT/prebuilt/mediamtx/linux-arm64"
GOMODCACHE="${GOMODCACHE:-$SRC_ROOT/go-mod-cache}"
FORCE="${FORCE:-0}"

read_tag() {
  if [[ -n "${MEDIAMTX_VERSION:-}" ]]; then
    echo "$MEDIAMTX_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" "v1.19.2"
}

TAG="$(read_tag)"
TAG_NO_V="${TAG#v}"
REPO="${MEDIAMTX_REPO:-https://github.com/bluenviron/mediamtx.git}"
# Upstream renamed linux_arm64v8 → linux_arm64 around the 1.12+ releases.
RELEASE_URL_PRIMARY="https://github.com/bluenviron/mediamtx/releases/download/${TAG}/mediamtx_${TAG_NO_V}_linux_arm64.tar.gz"
RELEASE_URL_LEGACY="https://github.com/bluenviron/mediamtx/releases/download/${TAG}/mediamtx_${TAG_NO_V}_linux_arm64v8.tar.gz"
CACHE_TAR="$SRC_ROOT/mediamtx_${TAG_NO_V}_linux_arm64.tar.gz"

# App-owned: binary stays in prebuilt/ and is copied into /opt/hmi/bin by make build-app.
# Do not sync into rootfs-overlay.

if prebuilt_ready "$OUT_DIR" && [[ "$FORCE" != "1" ]]; then
  echo "build-mediamtx: prebuilt ready at $OUT_DIR (App ships via make build-app)"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$REPO_DIR" "$OUT_DIR" "$CACHE_TAR"
fi

mkdir -p "$SRC_ROOT" "$OUT_DIR"

download_release() {
  if [[ -f "$CACHE_TAR" ]]; then
    echo "build-mediamtx: using cached $CACHE_TAR"
  else
    local url=""
    for cand in "$RELEASE_URL_PRIMARY" "$RELEASE_URL_LEGACY"; do
      echo "build-mediamtx: trying ${cand} ..."
      if curl -fL --retry 3 --retry-delay 2 -o "$CACHE_TAR" "$cand"; then
        url="$cand"
        break
      fi
      rm -f "$CACHE_TAR"
    done
    if [[ -z "$url" ]]; then
      echo "ERROR: could not download MediaMTX ${TAG} linux/arm64 release" >&2
      return 1
    fi
  fi
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  tar -xzf "$CACHE_TAR" -C "$OUT_DIR"
  if [[ ! -x "$OUT_DIR/mediamtx" ]]; then
    echo "ERROR: mediamtx binary missing after extract" >&2
    return 1
  fi
  chmod 755 "$OUT_DIR/mediamtx"
  prebuilt_stamp "$OUT_DIR" "${TAG}-linux-arm64"
  bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
  echo "build-mediamtx: release → $OUT_DIR/mediamtx"
}

build_from_source() {
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not found" >&2
    exit 1
  fi
  mkdir -p "$GOMODCACHE"
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo "build-mediamtx: cloning ${TAG} ..."
    git clone --depth 1 --branch "$TAG" "$REPO" "$REPO_DIR"
  else
    echo "build-mediamtx: updating checkout to ${TAG} ..."
    git -C "$REPO_DIR" fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null || \
      git -C "$REPO_DIR" fetch origin
    git -C "$REPO_DIR" checkout -f "$TAG"
  fi
  if ! command -v go >/dev/null 2>&1; then
    echo "build-mediamtx: go not found — source at $REPO_DIR; install Go 1.22+ and re-run" >&2
    exit 1
  fi
  export GOMODCACHE
  echo "build-mediamtx: go mod download ..."
  (cd "$REPO_DIR" && go mod download)
  mkdir -p "$OUT_DIR"
  export CGO_ENABLED=0
  echo "build-mediamtx: go generate (host) ..."
  (cd "$REPO_DIR" && unset GOOS GOARCH GOARM && go generate ./...)
  echo "build-mediamtx: go build linux/arm64 → prebuilt/ ..."
  (
    cd "$REPO_DIR"
    GOOS=linux GOARCH=arm64 go build -trimpath \
      -ldflags="-s -w -checklinkname=0" \
      -o "$OUT_DIR/mediamtx" .
  )
  chmod 755 "$OUT_DIR/mediamtx"
  prebuilt_stamp "$OUT_DIR" "${TAG}-linux-arm64"
  bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
  echo "build-mediamtx: wrote $OUT_DIR/mediamtx (${TAG}-linux-arm64)"
}

if download_release; then
  exit 0
fi

echo "build-mediamtx: release download failed — falling back to go build" >&2
build_from_source
