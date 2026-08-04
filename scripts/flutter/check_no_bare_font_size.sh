#!/usr/bin/env bash
# Fail if production Dart under app/lws_hmi/lib uses:
#   1) bare numeric fontSize (e.g. fontSize: 16)
#   2) AppTypography.*Size in business pages (prefer context.hmiTypography.*)
#
# Allowed bare / Size exceptions:
#   - lib/l10n/** (generated)
#   - lib/ui/demo/** (demo pages)
#   - lib/app/theme/** (token definitions)
#   - specialty layout/token / CustomPainter / dashboard scaling files listed below
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT_DIR/app/lws_hmi/lib"

if ! command -v rg >/dev/null 2>&1; then
  echo "[error] ripgrep (rg) required for check-typography" >&2
  exit 1
fi

COMMON_GLOBS=(
  --glob '!**/l10n/**'
  --glob '!**/ui/demo/**'
  --glob '!**/app/theme/**'
)

# Match fontSize: <number> with optional .0 / decimal.
BARE_PATTERN='fontSize:\s*[0-9]+(\.[0-9]+)?'

bare_hits="$(
  rg -n "${COMMON_GLOBS[@]}" -e "$BARE_PATTERN" "$LIB" || true
)"

if [[ -n "$bare_hits" ]]; then
  echo "[error] bare numeric fontSize found in production lib." >&2
  echo "[error] Use AppTypography / HmiTypography tokens instead." >&2
  echo "$bare_hits" >&2
  exit 1
fi

# Business pages must not read AppTypography.*Size; specialty files may.
SIZE_PATTERN='AppTypography\.\w+Size'
SIZE_ALLOW_GLOBS=(
  --glob '!**/process_mode/domain/process_mode_tokens.dart'
  --glob '!**/warn_alarm/presentation/warn_dialog_body.dart'
  --glob '!**/process_mode/presentation/engineer_ramp_chart.dart'
  --glob '!**/process_mode/presentation/quick_mode_laser_dashboard.dart'
  --glob '!**/process_mode/presentation/quick_mode_value_pick.dart'
  --glob '!**/process_mode/presentation/process_mode_outline_button.dart'
  --glob '!**/process_mode/presentation/process_mode_toast.dart'
  --glob '!**/work_mode/presentation/work_mode_status_bar.dart'
  --glob '!**/status_bar/call_back_home_button.dart'
  --glob '!**/home/presentation/home_page.dart'
  --glob '!**/home/presentation/custom_home_statistics_panel.dart'
)

size_hits="$(
  rg -n "${COMMON_GLOBS[@]}" "${SIZE_ALLOW_GLOBS[@]}" \
    -e "$SIZE_PATTERN" "$LIB/features" "$LIB/ui" 2>/dev/null || true
)"

if [[ -n "$size_hits" ]]; then
  echo "[error] AppTypography.*Size found in business pages." >&2
  echo "[error] Prefer context.hmiTypography.* (or allowlist specialty files)." >&2
  echo "$size_hits" >&2
  exit 1
fi

# Optional soft flag: CyberButton child TextStyle with fontSize override outside HmiButton.
# Report only (non-fatal) until migration finishes tightening.
cyber_override_hits="$(
  rg -n -U --multiline-dotall "${COMMON_GLOBS[@]}" \
    -e 'CyberButton\([^;]{0,800}?TextStyle\([^)]*fontSize:' \
    "$LIB/features" "$LIB/ui" 2>/dev/null || true
)"

if [[ -n "$cyber_override_hits" ]]; then
  echo "[warn] CyberButton + TextStyle(fontSize:…) still present (prefer HmiButton):" >&2
  echo "$cyber_override_hits" >&2
fi

echo "[ok] typography: no bare fontSize; business AppTypography.*Size clean"
