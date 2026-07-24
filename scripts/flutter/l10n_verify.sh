#!/usr/bin/env bash
# Ensure child ARBs and generated l10n match parent templates.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
L10N_DIR="$ROOT_DIR/app/hmi/lib/l10n"
FLUTTER="$("$ROOT_DIR/scripts/flutter/l10n_flutter.sh")"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[error] python3 not found in PATH" >&2
  exit 1
fi

python3 "$ROOT_DIR/scripts/flutter/sync_l10n_child_arbs.py"

if ! git -C "$ROOT_DIR" diff --quiet -- "$L10N_DIR"; then
  echo "[error] l10n ARBs are out of sync. Run: make l10n" >&2
  git -C "$ROOT_DIR" diff --stat -- "$L10N_DIR" >&2 || true
  exit 1
fi

cd "$ROOT_DIR/app/hmi"
"$FLUTTER" gen-l10n

if ! git -C "$ROOT_DIR" diff --quiet -- "$L10N_DIR"; then
  echo "[error] AppLocalizations codegen is stale. Run: make l10n" >&2
  git -C "$ROOT_DIR" diff --stat -- "$L10N_DIR" >&2 || true
  exit 1
fi

echo "[ok] l10n: ARBs and generated localizations are in sync"
