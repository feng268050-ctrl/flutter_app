#!/usr/bin/env bash
set -euo pipefail

# Download RKNN-Toolkit2 wheel + Python requirements into scripts/make/rknn/_cache/.
#
# Usage:
#   scripts/make/fetch-rknn-toolkit.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RKNN_DIR="$ROOT/scripts/make/rknn"
VERSION_FILE="$RKNN_DIR/VERSION"
CACHE_DIR="$RKNN_DIR/_cache"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: missing $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
WHEEL_NAME="rknn_toolkit2-${VERSION}-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
REQ_NAME="requirements_cp38-${VERSION}.txt"
TORCH_WHEEL_NAME="torch-2.4.0+cpu-cp38-cp38-linux_x86_64.whl"
WHEEL_PATH="$CACHE_DIR/$WHEEL_NAME"
REQ_PATH="$CACHE_DIR/$REQ_NAME"
TORCH_WHEEL_PATH="$CACHE_DIR/$TORCH_WHEEL_NAME"

BASE_URL="https://github.com/airockchip/rknn-toolkit2/raw/v${VERSION}/rknn-toolkit2/packages/x86_64"
TORCH_URL="https://download.pytorch.org/whl/cpu/torch-2.4.0%2Bcpu-cp38-cp38-linux_x86_64.whl"
TORCH_URL_FALLBACK="https://download.pytorch.org/whl/cpu/${TORCH_WHEEL_NAME}"
# Published torch-2.4.0+cpu cp38 linux x86_64 wheel is ~195 MiB.
TORCH_MIN_BYTES=190000000

torch_wheel_ready() {
  [[ -f "$TORCH_WHEEL_PATH" ]] || return 1
  local size
  size="$(wc -c < "$TORCH_WHEEL_PATH" | tr -d '[:space:]')"
  [[ "$size" -ge "$TORCH_MIN_BYTES" ]]
}

rknn_cache_ready() {
  [[ -f "$WHEEL_PATH" && -f "$REQ_PATH" ]] && torch_wheel_ready
}

if rknn_cache_ready; then
  echo "fetch-rknn-toolkit: RKNN-Toolkit2 ${VERSION} already cached at $CACHE_DIR"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

if [[ ! -f "$WHEEL_PATH" ]]; then
  echo "fetch-rknn-toolkit: downloading ${BASE_URL}/${WHEEL_NAME} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$WHEEL_PATH" "${BASE_URL}/${WHEEL_NAME}"
else
  echo "fetch-rknn-toolkit: using cached wheel $WHEEL_PATH"
fi

if [[ ! -f "$REQ_PATH" ]]; then
  echo "fetch-rknn-toolkit: downloading ${BASE_URL}/${REQ_NAME} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$REQ_PATH" "${BASE_URL}/${REQ_NAME}"
else
  echo "fetch-rknn-toolkit: using cached requirements $REQ_PATH"
fi

if ! torch_wheel_ready; then
  echo "fetch-rknn-toolkit: downloading CPU PyTorch wheel (resume-capable) ..."
  if ! curl -fL --retry 5 --retry-delay 3 -C - -o "$TORCH_WHEEL_PATH" "$TORCH_URL"; then
    echo "fetch-rknn-toolkit: retrying torch download from fallback URL ..."
    curl -fL --retry 5 --retry-delay 3 -C - -o "$TORCH_WHEEL_PATH" "$TORCH_URL_FALLBACK"
  fi
  if ! torch_wheel_ready; then
    echo "ERROR: incomplete torch wheel at $TORCH_WHEEL_PATH (re-run fetch to resume)" >&2
    exit 1
  fi
else
  echo "fetch-rknn-toolkit: using cached torch wheel $TORCH_WHEEL_PATH"
fi

echo "fetch-rknn-toolkit: ready (RKNN-Toolkit2 ${VERSION}, x86_64 cp38 + torch cpu)"
