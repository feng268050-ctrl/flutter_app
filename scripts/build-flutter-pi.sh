#!/usr/bin/env bash
# Prefetch flutter-pi source into .cache/ (compile fallback).
# Skipped when prebuilt/flutter-pi/<commit>/ is present.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-pi.version"
REPO="${FLUTTER_PI_REPO:-https://github.com/ardera/flutter-pi.git}"

read_version() {
  if [[ -n "${FLUTTER_PI_VERSION:-}" ]]; then
    echo "$FLUTTER_PI_VERSION"
    return 0
  fi
  read_version_file "$VERSION_FILE" ""
}

VERSION="$(read_version)"
if [[ -z "$VERSION" ]]; then
  grep -E '^FLUTTER_PI_VERSION[[:space:]]*=' \
    "$ROOT/overlay/buildroot/package/flutter-pi/flutter-pi.mk" 2>/dev/null \
    | awk '{print $3}' || true
fi
if [[ -z "$VERSION" ]]; then
  echo "ERROR: could not determine FLUTTER_PI_VERSION" >&2
  exit 1
fi

PI_PREBUILT="$ROOT/prebuilt/flutter-pi/${VERSION}"
SRC="$ROOT/.cache/flutter-pi/src"
FORCE="${FORCE:-0}"

if prebuilt_ready "$PI_PREBUILT" && [[ "$FORCE" != "1" ]]; then
  echo "flutter-pi: prebuilt ready at $PI_PREBUILT (skipping source fetch)"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ROOT/.cache/flutter-pi"
fi

mkdir -p "$(dirname "$SRC")"

if [[ ! -d "$SRC/.git" ]]; then
  echo "flutter-pi: cloning $REPO ..."
  git clone "$REPO" "$SRC"
fi

echo "flutter-pi: checkout $VERSION ..."
git -C "$SRC" fetch origin
git -C "$SRC" checkout -f "$VERSION"

echo "flutter-pi: ready at $SRC ($(git -C "$SRC" rev-parse --short HEAD))"
echo "  Tip: after make build-rootfs, run make build-prebuilt and commit prebuilt/."
