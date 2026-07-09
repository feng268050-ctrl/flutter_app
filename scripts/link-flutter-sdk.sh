#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK="$ROOT/flutter-sdk"
VERSION_FILE="$ROOT/overlay/buildroot/flutter-sdk.version"
LEGACY_ROOT="$ROOT/prebuilt/flutter-sdk"

expand_path() {
  bash "$SCRIPTS/expand-path.sh" "$1"
}

read_flutter_version() {
  if [[ -f "$VERSION_FILE" ]]; then
    tr -d '[:space:]' < "$VERSION_FILE"
    return 0
  fi
  echo "3.24.4"
}

default_flutter_sdk_root() {
  local version
  version="$(read_flutter_version)"
  if [[ -n "${FLUTTER_SDK:-}" ]]; then
    expand_path "$FLUTTER_SDK"
  else
    echo "$HOME/Downloads/flutter-sdk-${version}"
  fi
}

resolve_flutter_sdk_root() {
  if [[ -n "${FLUTTER_SDK:-}" ]]; then
    expand_path "$FLUTTER_SDK"
    return 0
  fi
  if [[ -L "$LINK" ]]; then
    local install
    install="$(readlink -f "$LINK" 2>/dev/null || realpath "$LINK")"
    dirname "$install"
    return 0
  fi
  default_flutter_sdk_root
}

flutter_sdk_install() {
  echo "$(resolve_flutter_sdk_root)/install"
}

migrate_legacy_prebuilt() {
  local root="$1"
  local install="$root/install"
  if [[ -d "$install" ]]; then
    return 0
  fi
  if [[ ! -d "$LEGACY_ROOT/install" ]]; then
    return 0
  fi
  echo "Migrating legacy $LEGACY_ROOT -> $root ..."
  mkdir -p "$(dirname "$root")"
  mv "$LEGACY_ROOT" "$root"
}

if [[ "${1:-}" == "--print" ]]; then
  flutter_sdk_install
  exit 0
fi

if [[ "${1:-}" == "--print-root" ]]; then
  resolve_flutter_sdk_root
  exit 0
fi

ROOT_DIR="$(resolve_flutter_sdk_root)"
INSTALL="$ROOT_DIR/install"

migrate_legacy_prebuilt "$ROOT_DIR"

if [[ ! -d "$INSTALL" ]]; then
  cat >&2 <<EOF
ERROR: Flutter SDK not found at:
  $INSTALL

Download and precache it, then link:
  make fetch-flutter-sdk

Or point FLUTTER_SDK at an existing tree (must contain install/ with bin/flutter):
  export FLUTTER_SDK=~/Downloads/flutter-sdk-3.24.4
  make link-flutter-sdk
EOF
  exit 1
fi

if [[ -L "$LINK" ]]; then
  rm -f "$LINK"
elif [[ -e "$LINK" ]]; then
  echo "ERROR: $LINK exists and is not a symlink" >&2
  exit 1
fi

ln -s "$INSTALL" "$LINK"
echo "Linked $LINK -> $INSTALL"
