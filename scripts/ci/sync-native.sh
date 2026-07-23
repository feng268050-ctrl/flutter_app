#!/usr/bin/env bash
# Deprecated alias: use scripts/ci/sync-ai.sh / `make sync-ai`.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "WARN: sync-native is renamed to sync-ai; forwarding..." >&2
exec bash "${SCRIPT_DIR}/sync-ai.sh" "$@"
