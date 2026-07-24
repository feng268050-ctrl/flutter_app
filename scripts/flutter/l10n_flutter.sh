#!/usr/bin/env bash
# Resolve Flutter binary: pinned flutter-sdk/ preferred, else PATH.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -x "$ROOT_DIR/flutter-sdk/bin/flutter" ]]; then
  echo "$ROOT_DIR/flutter-sdk/bin/flutter"
  exit 0
fi

if command -v flutter >/dev/null 2>&1; then
  command -v flutter
  exit 0
fi

echo "[error] flutter not found (expected flutter-sdk/bin/flutter or PATH)" >&2
exit 1
