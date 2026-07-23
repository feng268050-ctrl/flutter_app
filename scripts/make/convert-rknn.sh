#!/usr/bin/env bash
set -euo pipefail

# ONNX → RKNN via RKNN-Toolkit2 in a linux/amd64 Docker container.
# On Apple Silicon Macs, Docker Desktop runs the container under Rosetta/QEMU.
#
# Usage:
#   scripts/make/convert-rknn.sh
#
# Environment (also overridable via `make rknn RKNN_*=...`):
#   RKNN_PLATFORM   default rk3566
#   RKNN_DTYPE        default i8  (i8 | u8 | fp)
#   RKNN_ONNX         optional ONNX path (default: auto under ai-library/)
#   RKNN_OUTPUT       optional output .rknn path
#   RKNN_CALIB_ZIP    optional calibration zip
#   RKNN_CALIB_DIR    optional calibration image directory
#   RKNN_DATASET_TXT  optional existing dataset list
#   RKNN_DOCKER_IMAGE default lws-rknn-toolkit:<VERSION>
#   RKNN_FORCE_CONVERT=1       bypass ONNX SHA-256 cache and re-run Docker conversion
#   REBUILD_IMAGE=1    force rebuild Docker image (preferred)
#   RKNN_REBUILD=1     legacy alias (deprecated; use REBUILD_IMAGE=1)
#   RKNN_SKIP_DOCKER_BUILD=1  legacy: skip rebuild (deprecated)
#
# ONNX→RKNN results are cached under ai-library/_cache/onnx2rknn/ keyed by
# SHA-256(onnx) + platform + dtype. Unchanged ONNX skips Docker conversion.

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$_SCRIPT_DIR/../.." && pwd)"
RKNN_DIR="$ROOT/scripts/make/rknn"
AI_LIBRARY="$ROOT/ai-library"

VERSION="$(tr -d '[:space:]' < "$RKNN_DIR/VERSION")"
DOCKER_IMAGE="${RKNN_DOCKER_IMAGE:-lws-rknn-toolkit:${VERSION}}"
DOCKER_PLATFORM="${RKNN_DOCKER_PLATFORM:-linux/amd64}"

RKNN_PLATFORM="${RKNN_PLATFORM:-rk3566}"
RKNN_DTYPE="${RKNN_DTYPE:-i8}"

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    cat >&2 <<'EOF'
ERROR: docker not found.

Install Docker Desktop, then re-run `make rknn`.
On Apple Silicon, the converter runs as linux/amd64 (Rosetta/QEMU via Docker).
EOF
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker daemon is not running. Start Docker Desktop and retry." >&2
    exit 1
  fi
}

resolve_output_host() {
  if [[ -n "${RKNN_OUTPUT:-}" ]]; then
    local out_host
    out_host="$(cd "$(dirname "$RKNN_OUTPUT")" && pwd)/$(basename "$RKNN_OUTPUT")"
    if [[ "$out_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_OUTPUT must live under ai-library/: $RKNN_OUTPUT" >&2
      exit 1
    fi
    echo "$out_host"
    return 0
  fi

  local onnx_path="$1"
  local stem
  stem="$(basename "$onnx_path" .onnx)"
  echo "$AI_LIBRARY/${stem}_${RKNN_PLATFORM}_${RKNN_DTYPE}.rknn"
}

try_cached_conversion() {
  local onnx_path output_path onnx_hash
  onnx_path="$(rknn_resolve_onnx_host "$AI_LIBRARY" "${RKNN_ONNX:-}")" || exit 1
  output_path="$(resolve_output_host "$onnx_path")"
  onnx_hash="$(_rknn_compute_sha256 "$onnx_path")" || exit 1

  if [[ "${RKNN_FORCE_CONVERT:-}" == "1" ]]; then
    echo "make rknn: RKNN_FORCE_CONVERT=1 (skipping ONNX hash cache)" >&2
    _RKNN_ONNX_HOST="$onnx_path"
    _RKNN_OUTPUT_HOST="$output_path"
    _RKNN_ONNX_HASH="$onnx_hash"
    return 1
  fi

  if rknn_restore_cached_rknn "$onnx_hash" "$RKNN_PLATFORM" "$RKNN_DTYPE" "$output_path"; then
    return 0
  fi

  echo "make rknn: cache miss onnx_sha256=${onnx_hash:0:12}... platform=${RKNN_PLATFORM} dtype=${RKNN_DTYPE}" >&2
  _RKNN_ONNX_HOST="$onnx_path"
  _RKNN_OUTPUT_HOST="$output_path"
  _RKNN_ONNX_HASH="$onnx_hash"
  return 1
}

ensure_ai_library() {
  if [[ ! -d "$AI_LIBRARY" ]]; then
    echo "ERROR: ai-library directory not found: $AI_LIBRARY" >&2
    echo "Create ai-library/ and place .onnx + calibration .zip there." >&2
    exit 1
  fi
}

build_docker_image() {
  # Default behavior: reuse existing image if present (like make emulator).
  # Set REBUILD_IMAGE=1 to force rebuild. For backward compatibility:
  # - RKNN_REBUILD=1 forces rebuild (deprecated)
  # - RKNN_SKIP_DOCKER_BUILD=1 disables rebuilding (deprecated)

  if [[ "${REBUILD_IMAGE:-}" == "1" || "${RKNN_REBUILD:-}" == "1" ]]; then
    local reason="REBUILD_IMAGE=1"
    [[ "${REBUILD_IMAGE:-}" != "1" ]] && reason="RKNN_REBUILD=1 (deprecated)"
    echo "make rknn: rebuilding Docker image ${DOCKER_IMAGE} (${DOCKER_PLATFORM}) (${reason}) ..."
    docker build \
      --platform "$DOCKER_PLATFORM" \
      --build-arg "RKNN_VERSION=${VERSION}" \
      -t "$DOCKER_IMAGE" \
      "$RKNN_DIR"
    return 0
  fi

  if docker image inspect "$DOCKER_IMAGE" >/dev/null 2>&1; then
    if [[ "${RKNN_SKIP_DOCKER_BUILD:-}" == "1" ]]; then
      echo "make rknn: using existing Docker image (RKNN_SKIP_DOCKER_BUILD=1; deprecated)"
    else
      echo "make rknn: using existing Docker image (set REBUILD_IMAGE=1 to rebuild)"
    fi
    return 0
  fi

  echo "make rknn: Docker image not found; building ${DOCKER_IMAGE} (${DOCKER_PLATFORM}) ..."
  docker build \
    --platform "$DOCKER_PLATFORM" \
    --build-arg "RKNN_VERSION=${VERSION}" \
    -t "$DOCKER_IMAGE" \
    "$RKNN_DIR"
}

run_conversion() {
  local -a docker_args=(
    run
    --rm
    --platform "$DOCKER_PLATFORM"
    -v "${AI_LIBRARY}:/work/ai-library"
  )

  local -a py_args=(
    --ai-library /work/ai-library
    --platform "$RKNN_PLATFORM"
    --dtype "$RKNN_DTYPE"
  )

  if [[ -n "${RKNN_ONNX:-}" ]]; then
    local onnx_host onnx_base
    onnx_host="$(cd "$(dirname "$RKNN_ONNX")" && pwd)/$(basename "$RKNN_ONNX")"
    if [[ "$onnx_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_ONNX must live under ai-library/: $RKNN_ONNX" >&2
      exit 1
    fi
    onnx_base="${onnx_host#"$AI_LIBRARY/"}"
    py_args+=(--onnx "/work/ai-library/${onnx_base}")
  fi

  if [[ -n "${RKNN_OUTPUT:-}" ]]; then
    local out_host out_base
    out_host="$(cd "$(dirname "$RKNN_OUTPUT")" && pwd)/$(basename "$RKNN_OUTPUT")"
    if [[ "$out_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_OUTPUT must live under ai-library/: $RKNN_OUTPUT" >&2
      exit 1
    fi
    out_base="${out_host#"$AI_LIBRARY/"}"
    py_args+=(--output "/work/ai-library/${out_base}")
  fi

  if [[ -n "${RKNN_CALIB_ZIP:-}" ]]; then
    local zip_host zip_base
    zip_host="$(cd "$(dirname "$RKNN_CALIB_ZIP")" && pwd)/$(basename "$RKNN_CALIB_ZIP")"
    if [[ "$zip_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_CALIB_ZIP must live under ai-library/: $RKNN_CALIB_ZIP" >&2
      exit 1
    fi
    zip_base="${zip_host#"$AI_LIBRARY/"}"
    py_args+=(--calib-zip "/work/ai-library/${zip_base}")
  fi

  if [[ -n "${RKNN_CALIB_DIR:-}" ]]; then
    local dir_host dir_base
    dir_host="$(cd "$RKNN_CALIB_DIR" && pwd)"
    if [[ "$dir_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_CALIB_DIR must live under ai-library/: $RKNN_CALIB_DIR" >&2
      exit 1
    fi
    dir_base="${dir_host#"$AI_LIBRARY/"}"
    py_args+=(--calib-dir "/work/ai-library/${dir_base}")
  fi

  if [[ -n "${RKNN_DATASET_TXT:-}" ]]; then
    local txt_host txt_base
    txt_host="$(cd "$(dirname "$RKNN_DATASET_TXT")" && pwd)/$(basename "$RKNN_DATASET_TXT")"
    if [[ "$txt_host" != "$AI_LIBRARY/"* ]]; then
      echo "ERROR: RKNN_DATASET_TXT must live under ai-library/: $RKNN_DATASET_TXT" >&2
      exit 1
    fi
    txt_base="${txt_host#"$AI_LIBRARY/"}"
    py_args+=(--dataset-txt "/work/ai-library/${txt_base}")
  fi

  if [[ "${RKNN_VERBOSE:-}" == "1" ]]; then
    py_args+=(--verbose)
  fi

  echo "make rknn: platform=${RKNN_PLATFORM} dtype=${RKNN_DTYPE} ai-library=${AI_LIBRARY}"
  docker "${docker_args[@]}" "$DOCKER_IMAGE" "${py_args[@]}"
}

require_docker
ensure_ai_library
bash "$ROOT/scripts/make/fetch-rknn-toolkit.sh"

# shellcheck source=rknn-cache.sh
source "$RKNN_DIR/../rknn-cache.sh"

_RKNN_ONNX_HOST=""
_RKNN_OUTPUT_HOST=""
_RKNN_ONNX_HASH=""

if try_cached_conversion; then
  exit 0
fi

build_docker_image
export RKNN_OUTPUT="$_RKNN_OUTPUT_HOST"
run_conversion

rknn_save_cached_rknn "$_RKNN_ONNX_HOST" "$RKNN_PLATFORM" "$RKNN_DTYPE" "$_RKNN_OUTPUT_HOST" "$_RKNN_ONNX_HASH"
