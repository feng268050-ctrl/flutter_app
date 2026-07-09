#!/usr/bin/env bash
# Download RKNN-Toolkit2 wheel + requirements (host dev — ONNX→RKNN model convert).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT/overlay/third-party/rknn-toolkit.version"
CACHE_DIR="$ROOT/.cache/rknn-toolkit"
FORCE="${FORCE:-0}"

read_version() {
  if [[ -n "${RKNN_TOOLKIT_VERSION:-}" ]]; then
    echo "$RKNN_TOOLKIT_VERSION"
    return 0
  fi
  if [[ -f "$VERSION_FILE" ]]; then
    tr -d '[:space:]' < "$VERSION_FILE"
    return 0
  fi
  echo "2.3.2"
}

VERSION="$(read_version)"
WHEEL_NAME="rknn_toolkit2-${VERSION}-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
REQ_NAME="requirements_cp38-${VERSION}.txt"
TORCH_WHEEL_NAME="torch-2.4.0+cpu-cp38-cp38-linux_x86_64.whl"
WHEEL_PATH="$CACHE_DIR/$WHEEL_NAME"
REQ_PATH="$CACHE_DIR/$REQ_NAME"
TORCH_WHEEL_PATH="$CACHE_DIR/$TORCH_WHEEL_NAME"

BASE_URL="https://github.com/airockchip/rknn-toolkit2/raw/v${VERSION}/rknn-toolkit2/packages/x86_64"
TORCH_URL="https://download.pytorch.org/whl/cpu/torch-2.4.0%2Bcpu-cp38-cp38-linux_x86_64.whl"
TORCH_URL_FALLBACK="https://download.pytorch.org/whl/cpu/${TORCH_WHEEL_NAME}"
TORCH_MIN_BYTES=190000000

if [[ "$FORCE" == "1" ]]; then
  rm -f "$WHEEL_PATH" "$REQ_PATH" "$TORCH_WHEEL_PATH"
fi

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

mkdir -p "$CACHE_DIR"

if [[ ! -f "$WHEEL_PATH" ]]; then
  echo "fetch-rknn-toolkit: downloading ${BASE_URL}/${WHEEL_NAME} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$WHEEL_PATH" "${BASE_URL}/${WHEEL_NAME}"
fi

if [[ ! -f "$REQ_PATH" ]]; then
  echo "fetch-rknn-toolkit: downloading ${BASE_URL}/${REQ_NAME} ..."
  curl -fL --retry 3 --retry-delay 2 -o "$REQ_PATH" "${BASE_URL}/${REQ_NAME}"
fi

if ! torch_wheel_ready; then
  echo "fetch-rknn-toolkit: downloading CPU PyTorch wheel (resume-capable) ..."
  if ! curl -fL --retry 5 --retry-delay 3 -C - -o "$TORCH_WHEEL_PATH" "$TORCH_URL"; then
    echo "fetch-rknn-toolkit: retrying torch from fallback URL ..."
    curl -fL --retry 5 --retry-delay 3 -C - -o "$TORCH_WHEEL_PATH" "$TORCH_URL_FALLBACK"
  fi
  if ! torch_wheel_ready; then
    echo "ERROR: incomplete torch wheel at $TORCH_WHEEL_PATH (re-run to resume)" >&2
    exit 1
  fi
fi

echo "fetch-rknn-toolkit: ready (RKNN-Toolkit2 ${VERSION}, x86_64 cp38 + torch cpu)"
echo "  $CACHE_DIR"
