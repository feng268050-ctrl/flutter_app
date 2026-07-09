#!/usr/bin/env bash
# Re-export gstreamer + platform runtime prebuilt (alias for export-runtime-prebuilt.sh all).
# Prefer: make build-gstreamer / make build-platform-packages (compile + export in one step).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/scripts/export-runtime-prebuilt.sh" all "$@"
