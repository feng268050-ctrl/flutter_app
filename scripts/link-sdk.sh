#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_LINK="$ROOT/sdk"
DEFAULT_SDK="${LWS_HMI_SDK:-$HOME/Downloads/rk356x_linux6.1_20250730_1126/rk356x_linux6.1_20250730_1126}"

if [[ "${1:-}" == "--print" ]]; then
  if [[ -L "$SDK_LINK" ]]; then
    readlink -f "$SDK_LINK" 2>/dev/null || realpath "$SDK_LINK"
  elif [[ -d "$SDK_LINK" ]]; then
    realpath "$SDK_LINK"
  else
    echo "$DEFAULT_SDK"
  fi
  exit 0
fi

resolve_sdk() {
  if [[ -n "${LWS_HMI_SDK:-}" ]]; then
    echo "$LWS_HMI_SDK"
    return 0
  fi
  if [[ -L "$SDK_LINK" || -d "$SDK_LINK" ]]; then
    readlink -f "$SDK_LINK" 2>/dev/null || realpath "$SDK_LINK"
    return 0
  fi
  echo "$DEFAULT_SDK"
}

SDK="$(resolve_sdk)"

if [[ ! -d "$SDK" ]]; then
  cat >&2 <<EOF
ERROR: Rockchip Linux SDK not found at:
  $SDK

Extract the vendor tarball first, then either:
  export LWS_HMI_SDK=/path/to/rk356x_linux6.1_20250730_1126
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
