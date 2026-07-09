#!/usr/bin/env bash
# Prefetch host Flutter SDK into prebuilt/ (git-tracked) and .cache/ fallback.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/buildroot/flutter-sdk.version"
VERSION="$(read_version_file "$VERSION_FILE" "3.24.4")"

CACHE_DIR="$ROOT/.cache/flutter-sdk"
PREBUILT_ROOT="$ROOT/prebuilt/flutter-sdk"
PREBUILT_INSTALL="$PREBUILT_ROOT/install"
TARBALL="$CACHE_DIR/flutter_linux_${VERSION}-stable.tar.xz"
CACHE_INSTALL="$CACHE_DIR/install"
MARKER=".lws-precache-done"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"
FORCE="${FORCE:-0}"

if prebuilt_ready "$PREBUILT_ROOT" && [[ -f "$PREBUILT_INSTALL/$MARKER" ]] && [[ "$FORCE" != "1" ]]; then
  echo "flutter-sdk $VERSION: prebuilt ready at $PREBUILT_INSTALL"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -f "$TARBALL" "$CACHE_INSTALL/$MARKER" "$PREBUILT_INSTALL/$MARKER"
  rm -rf "$CACHE_INSTALL" "$PREBUILT_INSTALL"
  rm -f "$PREBUILT_ROOT/.lws-prebuilt"
fi

mkdir -p "$CACHE_DIR"

if [[ ! -f "$TARBALL" ]]; then
  echo "flutter-sdk $VERSION: downloading $URL ..."
  curl -fL --retry 3 -o "$TARBALL" "$URL"
fi

install_tree="$CACHE_INSTALL"
if [[ ! -x "$install_tree/bin/flutter" ]]; then
  echo "flutter-sdk $VERSION: extracting ..."
  rm -rf "$install_tree"
  mkdir -p "$install_tree"
  tar -xJf "$TARBALL" -C "$install_tree" --strip-components=1
fi

if [[ ! -f "$install_tree/$MARKER" ]]; then
  echo "flutter-sdk $VERSION: running flutter precache (host engine artifacts) ..."
  HOME="$install_tree" \
  PATH="$install_tree/bin:${PATH}" \
  "$install_tree/bin/flutter" config --no-analytics >/dev/null
  HOME="$install_tree" \
  PATH="$install_tree/bin:${PATH}" \
  "$install_tree/bin/flutter" precache
  touch "$install_tree/$MARKER"
fi

echo "flutter-sdk $VERSION: syncing to prebuilt/ ..."
mkdir -p "$PREBUILT_ROOT"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$install_tree"/ "$PREBUILT_INSTALL"/
else
  rm -rf "$PREBUILT_INSTALL"
  mkdir -p "$PREBUILT_INSTALL"
  cp -a "$install_tree"/. "$PREBUILT_INSTALL"/
fi
prebuilt_stamp "$PREBUILT_ROOT" "$VERSION"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "flutter-sdk $VERSION: ready at $PREBUILT_INSTALL"
du -sh "$TARBALL" "$PREBUILT_INSTALL"
