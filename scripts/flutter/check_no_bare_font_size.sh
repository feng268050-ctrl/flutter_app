#!/usr/bin/env bash
# Fail if production Dart under app/lws_hmi/lib uses bare numeric fontSize
# (e.g. fontSize: 16). Prefer AppTypography / HmiDisplayTypography tokens.
#
# Allowed:
#   - lib/l10n/** (generated)
#   - lib/ui/demo/** (demo pages)
#   - lib/app/theme/** (token definitions themselves)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/app/lws_hmi/lib"

if ! command -v rg >/dev/null 2>&1; then
  echo "[error] ripgrep (rg) required for check-typography" >&2
  exit 1
fi

# Match fontSize: <number> with optional .0 / decimal.
PATTERN='fontSize:\s*[0-9]+(\.[0-9]+)?'

hits="$(
  rg -n --glob '!**/l10n/**' --glob '!**/ui/demo/**' --glob '!**/app/theme/**' \
    -e "$PATTERN" "$LIB" || true
)"

if [[ -n "$hits" ]]; then
  echo "[error] bare numeric fontSize found in production lib." >&2
  echo "[error] Use AppTypography.* / HmiDisplayTypography.* tokens instead." >&2
  echo "$hits" >&2
  exit 1
fi

echo "[ok] typography: no bare numeric fontSize in production lib"
