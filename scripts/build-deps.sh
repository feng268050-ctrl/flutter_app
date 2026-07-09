#!/usr/bin/env bash
# Download source + build versioned deps into prebuilt/ (Flutter stack).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/build-flutter-engine.sh"
bash "$ROOT/scripts/build-flutter-sdk.sh"
bash "$ROOT/scripts/build-flutter-pi.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "build-deps: done (prebuilt/ used when present; see prebuilt/README.md)"
