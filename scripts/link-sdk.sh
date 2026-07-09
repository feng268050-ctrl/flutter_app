#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDK_LINK="$ROOT/sdk"
DEFAULT_SDK_REL="Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126"

expand_path() {
  bash "$SCRIPTS/expand-path.sh" "$1"
}

default_sdk_path() {
  if [[ -n "${LINUX_SDK:-}" ]]; then
    expand_path "$LINUX_SDK"
  else
    echo "$HOME/$DEFAULT_SDK_REL"
  fi
}

resolve_sdk() {
  if [[ -n "${LINUX_SDK:-}" ]]; then
    expand_path "$LINUX_SDK"
    return 0
  fi
  if [[ -L "$SDK_LINK" || -d "$SDK_LINK" ]]; then
    readlink -f "$SDK_LINK" 2>/dev/null || realpath "$SDK_LINK"
    return 0
  fi
  default_sdk_path
}

if [[ "${1:-}" == "--print" ]]; then
  if [[ -L "$SDK_LINK" ]]; then
    readlink -f "$SDK_LINK" 2>/dev/null || realpath "$SDK_LINK"
  elif [[ -d "$SDK_LINK" ]]; then
    realpath "$SDK_LINK"
  else
    resolve_sdk
  fi
  exit 0
fi

SDK="$(resolve_sdk)"

if [[ ! -d "$SDK" ]]; then
  cat >&2 <<EOF
ERROR: Rockchip Linux SDK not found at:
  $SDK

Extract the vendor tarball first, then either:
  export LINUX_SDK=~/Downloads/rk356x_linux6.1_20250730_1126/...
  make link-sdk
EOF
  exit 1
fi

if [[ -L "$SDK_LINK" ]]; then
  rm -f "$SDK_LINK"
elif [[ -e "$SDK_LINK" ]]; then
  echo "ERROR: $SDK_LINK exists and is not a symlink" >&2
  exit 1
fi

ln -s "$SDK" "$SDK_LINK"
echo "Linked $SDK_LINK -> $SDK"
