#!/usr/bin/env bash
# Resolve repo-root flutter-sdk/ (real directory, gitignored) and migrate legacy layouts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  echo "3.41.9"
}

default_flutter_sdk_dir() {
  echo "$ROOT/flutter-sdk"
}

# FLUTTER_SDK may point at the SDK root (bin/flutter) or legacy parent with install/.
resolve_flutter_sdk_dir() {
  local path
  if [[ -n "${FLUTTER_SDK:-}" ]]; then
    path="$(expand_path "$FLUTTER_SDK")"
  else
    path="$(default_flutter_sdk_dir)"
  fi
  if [[ -x "$path/bin/flutter" ]]; then
    echo "$path"
    return 0
  fi
  if [[ -x "$path/install/bin/flutter" ]]; then
    echo "$path/install"
    return 0
  fi
  echo "$path"
}

flutter_sdk_usable() {
  local install="$1"
  local version="$2"
  [[ -x "$install/bin/flutter" ]] || return 1
  "$install/bin/flutter" --version 2>/dev/null | head -1 | grep -q "Flutter $version"
}

repair_flutter_sdk_tree() {
  local install="$1"
  local version="$2"
  if [[ ! -d "$install/.git" ]]; then
    return 0
  fi
  if ! git -C "$install" diff --quiet HEAD -- packages/flutter 2>/dev/null; then
    echo "flutter-sdk $version: packages/flutter has local edits (do not run flutter upgrade here); resetting ..."
    git -C "$install" reset --hard HEAD
  fi
  local active
  active="$("$install/bin/flutter" --version 2>/dev/null | head -1 || true)"
  if [[ "$active" != *"Flutter $version"* ]]; then
    echo "ERROR: Flutter SDK at $install is not $version (${active:-<unknown>})" >&2
    echo "Run: make refetch-flutter-sdk" >&2
    exit 1
  fi
}

migrate_to_flutter_sdk_dir() {
  local dest="$1"
  local version="$2"

  if [[ -L "$dest" ]]; then
    local target
    target="$(readlink -f "$dest" 2>/dev/null || realpath "$dest")"
    rm -f "$dest"
    if [[ -d "$target" ]]; then
      echo "Replacing flutter-sdk symlink with real directory ($target -> $dest) ..."
      mv "$target" "$dest"
      return 0
    fi
  fi

  if flutter_sdk_usable "$dest" "$version"; then
    return 0
  fi

  if [[ -e "$dest" && ! -x "$dest/bin/flutter" ]]; then
    echo "ERROR: $dest exists and is not a Flutter SDK (remove it or set FLUTTER_SDK)" >&2
    exit 1
  fi

  local candidates=()
  candidates+=("$ROOT/.host-deps/flutter-sdk-${version}/install")
  candidates+=("$HOME/Downloads/flutter-sdk-${version}/install")
  candidates+=("$LEGACY_ROOT/install")

  local src
  for src in "${candidates[@]}"; do
    [[ -x "$src/bin/flutter" ]] || continue
    echo "Migrating $src -> $dest ..."
    mkdir -p "$(dirname "$dest")"
    mv "$src" "$dest"
    return 0
  done

  # Legacy prebuilt/flutter-sdk was a parent tree with install/.
  if [[ -d "$LEGACY_ROOT/install" && ! -d "$dest" ]]; then
    echo "Migrating legacy $LEGACY_ROOT -> $(dirname "$dest") ..."
    mkdir -p "$(dirname "$dest")"
    mv "$LEGACY_ROOT" "$(dirname "$dest")/flutter-sdk-legacy-$$"
    if [[ -x "$(dirname "$dest")/flutter-sdk-legacy-$$/install/bin/flutter" ]]; then
      mv "$(dirname "$dest")/flutter-sdk-legacy-$$/install" "$dest"
      rm -rf "$(dirname "$dest")/flutter-sdk-legacy-$$"
      return 0
    fi
  fi
}

ensure_flutter_sdk() {
  local version install
  version="$(read_flutter_version)"
  install="$(resolve_flutter_sdk_dir)"

  if [[ -z "${FLUTTER_SDK:-}" ]]; then
    migrate_to_flutter_sdk_dir "$install" "$version"
  fi

  if ! flutter_sdk_usable "$install" "$version"; then
    cat >&2 <<EOF
ERROR: Flutter SDK not found at:
  $install

Download and precache on host:
  make fetch-flutter-sdk

Or point FLUTTER_SDK at an existing SDK root (directory containing bin/flutter):
  export FLUTTER_SDK=$ROOT/flutter-sdk
EOF
    exit 1
  fi

  repair_flutter_sdk_tree "$install" "$version"
}

if [[ "${1:-}" == "--print" || "${1:-}" == "--print-root" ]]; then
  resolve_flutter_sdk_dir
  exit 0
fi

ensure_flutter_sdk
install="$(resolve_flutter_sdk_dir)"
echo "flutter-sdk $(read_flutter_version): $install"
