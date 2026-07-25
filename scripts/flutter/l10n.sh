#!/usr/bin/env bash
# Sync parent–child ARB files, then run flutter gen-l10n for app/lws_hmi.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app/lws_hmi"
FLUTTER="$("$ROOT_DIR/scripts/flutter/l10n_flutter.sh")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[error] python3 not found in PATH" >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/flutter/sync_l10n_child_arbs.py"
cd "$APP_DIR"
"$FLUTTER" gen-l10n

echo "[ok] l10n: child ARBs synced and AppLocalizations regenerated"
