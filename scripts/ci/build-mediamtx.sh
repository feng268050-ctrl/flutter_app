#!/usr/bin/env bash
set -euo pipefail

# Build MediaMTX for Android arm64-v8a and copy into app assets.
#
# MUST use GOOS=android (not linux): Linux arm64 ELF cannot execute on Android (exit 126).
# Go 1.23+ also needs -checklinkname=0 for github.com/wlynxg/anet (used by MediaMTX).
#
# Requires: git, go 1.22+, network for `go mod download` and `go generate`.
#
# Usage:
#   scripts/ci/build-mediamtx.sh

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_FILE="$ROOT/tools/mediamtx/VERSION"
SRC_ROOT="$ROOT/tools/mediamtx/_src"
REPO_DIR="$SRC_ROOT/mediamtx"
OUT_DIR="$ROOT/app/src/main/assets/mediamtx/arm64-v8a"
GOMODCACHE="${GOMODCACHE:-$SRC_ROOT/go-mod-cache}"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: missing $VERSION_FILE" >&2
  exit 1
fi
TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"

if ! command -v go >/dev/null 2>&1; then
  echo "ERROR: go toolchain not found; install Go 1.22+" >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found" >&2
  exit 1
fi

mkdir -p "$SRC_ROOT" "$GOMODCACHE" "$OUT_DIR"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "build-mediamtx: cloning mediamtx ${TAG}..."
  git clone --depth 1 --branch "$TAG" https://github.com/bluenviron/mediamtx.git "$REPO_DIR"
else
  echo "build-mediamtx: updating mediamtx checkout to ${TAG}..."
  (cd "$REPO_DIR" && git fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null || true)
  (cd "$REPO_DIR" && git checkout -f "$TAG")
fi

export GOMODCACHE
export CGO_ENABLED=0

echo "build-mediamtx: go mod download..."
(
  cd "$REPO_DIR"
  go mod download
)

# go:generate helpers must run on the *host* arch (not cross-compiled).
echo "build-mediamtx: go generate (VERSION, hls.min.js, rpicamera assets)..."
(
  cd "$REPO_DIR"
  unset GOOS GOARCH GOARM
  go generate ./...
)

echo "build-mediamtx: go build android/arm64 (CGO_ENABLED=0, -checklinkname=0)..."
(
  cd "$REPO_DIR"
  GOOS=android GOARCH=arm64 go build -trimpath \
    -ldflags="-s -w -checklinkname=0" \
    -o "$OUT_DIR/mediamtx" .
)

chmod 755 "$OUT_DIR/mediamtx"
printf '%s\n' "${TAG}-android" > "$OUT_DIR/version.txt"
echo "build-mediamtx: wrote $OUT_DIR/mediamtx (${TAG}-android, GOOS=android)"
