#!/usr/bin/env bash
# Prefetch host Flutter SDK into FLUTTER_SDK (outside git) with .cache/ staging.
# Writes to FLUTTER_SDK/install on the host only — never rsync into Docker :ro mounts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION_FILE="$ROOT/overlay/buildroot/flutter-sdk.version"
VERSION="$(read_version_file "$VERSION_FILE" "3.24.4")"

CACHE_DIR="$ROOT/.cache/flutter-sdk"
FLUTTER_ROOT="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print-root)"
FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
TARBALL="$CACHE_DIR/flutter_linux_${VERSION}-stable.tar.xz"
CACHE_INSTALL="$CACHE_DIR/install"
MARKER=".lws-precache-done"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"
FORCE="${FORCE:-0}"
DOCKER_INSTALL="/work/lws-hmi/flutter-sdk"

flutter_install_ready() {
  [[ -x "${1}/bin/flutter" ]]
}

# Inside Docker the host FLUTTER_SDK tree is bind-mounted read-only at flutter-sdk/.
if [[ "${LWS_HMI_DOCKER:-}" == "1" ]]; then
  if flutter_install_ready "$DOCKER_INSTALL"; then
    echo "flutter-sdk $VERSION: ready at $DOCKER_INSTALL (read-only mount)"
    exit 0
  fi
  cat >&2 <<EOF
ERROR: host Flutter SDK not available in Docker.

On macOS, install/precache on the host first (writes to FLUTTER_SDK outside the container):
  make fetch-flutter-sdk

Then retry:
  make build-flutter-engine
EOF
  exit 1
fi

if flutter_install_ready "$FLUTTER_INSTALL" \
  && prebuilt_ready "$FLUTTER_ROOT" \
  && [[ -f "$FLUTTER_INSTALL/$MARKER" ]] \
  && [[ "$FORCE" != "1" ]]; then
  echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL"
  bash "$ROOT/scripts/link-flutter-sdk.sh"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -f "$TARBALL" "$CACHE_INSTALL/$MARKER" "$FLUTTER_INSTALL/$MARKER"
  rm -rf "$CACHE_INSTALL" "$FLUTTER_INSTALL"
  rm -f "$FLUTTER_ROOT/.lws-prebuilt"
fi

migrate_legacy() {
  local legacy="$ROOT/prebuilt/flutter-sdk"
  if [[ -d "$legacy/install" && ! -d "$FLUTTER_INSTALL" ]]; then
    echo "flutter-sdk $VERSION: migrating legacy prebuilt/flutter-sdk -> $FLUTTER_ROOT ..."
    mkdir -p "$(dirname "$FLUTTER_ROOT")"
    mv "$legacy" "$FLUTTER_ROOT"
  fi
}
migrate_legacy

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

echo "flutter-sdk $VERSION: syncing to $FLUTTER_INSTALL ..."
mkdir -p "$FLUTTER_ROOT"
if command -v rsync >/dev/null 2>&1; then
  # --no-owner --no-group --no-perms: avoid EROFS on cross-FS / Docker Desktop mounts
  rsync -a --delete --no-owner --no-group --no-perms --omit-dir-times "$install_tree"/ "$FLUTTER_INSTALL"/
else
  rm -rf "$FLUTTER_INSTALL"
  mkdir -p "$FLUTTER_INSTALL"
  cp -a "$install_tree"/. "$FLUTTER_INSTALL"/
fi
prebuilt_stamp "$FLUTTER_ROOT" "$VERSION"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"
bash "$ROOT/scripts/link-flutter-sdk.sh"

echo "flutter-sdk $VERSION: ready at $FLUTTER_INSTALL"
du -sh "$TARBALL" "$FLUTTER_INSTALL"
