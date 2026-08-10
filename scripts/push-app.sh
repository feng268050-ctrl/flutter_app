#!/usr/bin/env bash
# Deprecated entrypoint: unsigned SCP removed. Delegates to upgrade-app.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "NOTE: push-app is an alias of upgrade-app (signed HTTP path)." >&2
exec bash "$ROOT/scripts/upgrade-app.sh" "$@"
