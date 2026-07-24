#!/usr/bin/env bash
# Run flutter gen-l10n for app/hmi (run make l10n-sync first if parents changed).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/app/hmi"
FLUTTER="$("$ROOT_DIR/scripts/flutter/l10n_flutter.sh")"

cd "$APP_DIR"
"$FLUTTER" gen-l10n
echo "[ok] l10n-gen: AppLocalizations regenerated"
