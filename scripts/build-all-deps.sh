#!/usr/bin/env bash
# Build all versioned dependencies (P1 Flutter + P3/P5 dev).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/build-deps.sh"
bash "$ROOT/scripts/build-dev-deps.sh"

echo "build-all-deps: done"
