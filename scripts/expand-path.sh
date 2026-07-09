#!/usr/bin/env bash
# Expand leading ~ / ~/ to $HOME (bash does not do this for arbitrary variables).
set -euo pipefail

expand_user_path() {
  local p="${1:-}"
  if [[ "$p" == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ "$p" == "~/"* ]]; then
    printf '%s\n' "$HOME/${p:2}"
  else
    printf '%s\n' "$p"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  expand_user_path "${1:-}"
fi
