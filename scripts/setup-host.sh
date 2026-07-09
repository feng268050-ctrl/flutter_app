#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" == Darwin ]]; then
  bash "$ROOT/scripts/docker-build-image.sh"
  echo "Setup complete (macOS). Next: make docker-volume-init  then  make lunch"
else
  echo "Setup complete (Linux). Next: make lunch"
fi
