#!/usr/bin/env bash
# Dev-environment only: host SDK + model-conversion tools. Not deployed to the board.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/scripts/fetch-flutter-sdk.sh"
bash "$ROOT/scripts/fetch-rknn-toolkit.sh"
bash "$ROOT/scripts/sync-prebuilt-manifest.sh"

echo "build-dev-deps: host dev ready (FLUTTER_SDK, RKNN-Toolkit for ONNX→RKNN on x86)"
