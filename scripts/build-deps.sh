#!/usr/bin/env bash
# Full dependency prep: host dev environment + runtime prebuilt/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FORCE="${FORCE:-0}" bash "$ROOT/scripts/build-dev-deps.sh"
FORCE="${FORCE:-0}" bash "$ROOT/scripts/build-runtime-deps.sh"

echo "build-deps: done (build-dev-deps + build-runtime-deps)"
