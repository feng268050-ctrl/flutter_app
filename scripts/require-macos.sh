#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "ERROR: this command is only supported on macOS." >&2
  exit 1
fi
