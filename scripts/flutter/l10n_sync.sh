#!/usr/bin/env bash
# Regenerate slim child ARB files (en_US, zh_CN, zh_TW) from parents.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[error] python3 not found in PATH" >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/flutter/sync_l10n_child_arbs.py"
echo "[ok] l10n-sync: child ARB files updated"
