#!/usr/bin/env bash
# Clone MediaMTX source (if needed) and cross-compile into prebuilt/.
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
  read_version_file "$VERSION_FILE" "v1.11.3"
}

TAG="$(read_tag)"
REPO="${MEDIAMTX_REPO:-https://github.com/bluenviron/mediamtx.git}"

if prebuilt_ready "$OUT_DIR" && [[ "$FORCE" != "1" ]]; then
  echo "build-mediamtx: prebuilt ready at $OUT_DIR"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$REPO_DIR" "$OUT_DIR"
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found" >&2
  exit 1
fi

mkdir -p "$SRC_ROOT" "$GOMODCACHE"

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
(
  cd "$REPO_DIR"
  unset GOOS GOARCH GOARM
  go generate ./...
)

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
