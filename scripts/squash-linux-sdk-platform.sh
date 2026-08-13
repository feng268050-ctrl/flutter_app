#!/usr/bin/env bash
# Squash stable platform overlay (kernel + device script patches) into local linux-sdk/.
# Does NOT touch third-party / custom Buildroot packages (those stay on apply-overlay).
#
# Usage:
#   make squash-linux-sdk-platform
#   FORCE_PLATFORM_OVERLAY=1 …  # also used by apply-overlay to re-run platform steps
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-${SDK:-$ROOT/linux-sdk}}"
OVERLAY="$ROOT/overlay"

die() { echo "ERROR: $*" >&2; exit 1; }
[[ -d "$SDK" ]] || die "linux-sdk missing: $SDK"

echo "squash-linux-sdk-platform: SDK=$SDK"

# Reuse apply-overlay platform functions by sourcing with a guarded mode.
# Export flag so apply-overlay can run platform-only when invoked as:
#   LWS_PLATFORM_SQUASH=1 bash scripts/apply-overlay.sh
export SDK_DIR="$SDK"
export LWS_PLATFORM_SQUASH=1
bash "$ROOT/scripts/apply-overlay.sh" --platform-squash

# Ensure ownership marker exists (trim also writes this)
if [[ ! -f "$SDK/.lws-owned-tree" ]]; then
  {
    echo "# lws-hmi owned linux-sdk marker (W3)."
    echo "squashed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$SDK/.lws-owned-tree"
fi

# Record squash stamp inside marker
if ! grep -q '^platform_squashed=1' "$SDK/.lws-owned-tree" 2>/dev/null; then
  echo "platform_squashed=1" >> "$SDK/.lws-owned-tree"
fi

echo "squash-linux-sdk-platform: done (kernel + device patches applied; third-party packages unchanged)"
echo "NOTE: overlay/kernel and squashed device diffs are delete-only thereafter; do not add new kernel patches under overlay/kernel — edit the owned tree or re-run squash after intentional overlay updates."
