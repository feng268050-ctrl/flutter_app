#!/usr/bin/env bash
# ONNX → RKNN conversion cache keyed by ONNX SHA-256 + platform + dtype.

_rknn_cache_dir() {
  echo "${AI_LIBRARY}/_cache/onnx2rknn"
}

_rknn_compute_sha256() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  else
    echo "ERROR: need shasum or sha256sum to fingerprint ONNX" >&2
    return 1
  fi
}

_rknn_cache_basename() {
  local onnx_hash="$1"
  local platform="$2"
  local dtype="$3"
  printf '%s_%s_%s' "$onnx_hash" "$platform" "$dtype"
}

rknn_cache_artifact_path() {
  local onnx_hash="$1"
  local platform="$2"
  local dtype="$3"
  echo "$(_rknn_cache_dir)/$(_rknn_cache_basename "$onnx_hash" "$platform" "$dtype").rknn"
}

rknn_cache_meta_path() {
  local onnx_hash="$1"
  local platform="$2"
  local dtype="$3"
  echo "$(_rknn_cache_dir)/$(_rknn_cache_basename "$onnx_hash" "$platform" "$dtype").meta.json"
}

# Resolve ONNX under ai-library (mirrors scripts/make/rknn/onnx_to_rknn.py defaults).
rknn_resolve_onnx_host() {
  local ai_library="$1"
  local explicit="${2:-}"

  if [[ -n "$explicit" ]]; then
    local path
    path="$(cd "$(dirname "$explicit")" && pwd)/$(basename "$explicit")"
    if [[ ! -f "$path" ]]; then
      echo "ERROR: RKNN_ONNX not found: $explicit" >&2
      return 1
    fi
    if [[ "$path" != "$ai_library/"* ]]; then
      echo "ERROR: RKNN_ONNX must live under ai-library/: $explicit" >&2
      return 1
    fi
    echo "$path"
    return 0
  fi

  local default="$ai_library/det_raw_head.onnx"
  if [[ -f "$default" ]]; then
    echo "$default"
    return 0
  fi

  local -a matches=()
  local match
  shopt -s nullglob
  matches=("$ai_library"/*.onnx)
  shopt -u nullglob

  if ((${#matches[@]} == 1)); then
    echo "${matches[0]}"
    return 0
  fi
  if ((${#matches[@]} > 1)); then
    echo "ERROR: multiple ONNX files under $ai_library; set RKNN_ONNX" >&2
    return 1
  fi

  echo "ERROR: no ONNX under $ai_library (expected det_raw_head.onnx or RKNN_ONNX=...)" >&2
  return 1
}

# Returns 0 when a cached artifact was restored into output_path.
rknn_restore_cached_rknn() {
  local onnx_hash="$1"
  local platform="$2"
  local dtype="$3"
  local output_path="$4"

  local cached_rknn meta_path
  cached_rknn="$(rknn_cache_artifact_path "$onnx_hash" "$platform" "$dtype")"
  meta_path="$(rknn_cache_meta_path "$onnx_hash" "$platform" "$dtype")"

  if [[ ! -f "$cached_rknn" ]]; then
    return 1
  fi

  mkdir -p "$(dirname "$output_path")"
  cp -f "$cached_rknn" "$output_path"

  echo "make rknn: cache hit onnx_sha256=${onnx_hash:0:12}... platform=${platform} dtype=${dtype}" >&2
  echo "make rknn: restored $(basename "$output_path") from ${cached_rknn#$AI_LIBRARY/}" >&2
  if [[ -f "$meta_path" ]]; then
    echo "make rknn: cache meta ${meta_path#$AI_LIBRARY/}" >&2
  fi
  return 0
}

rknn_save_cached_rknn() {
  local onnx_path="$1"
  local platform="$2"
  local dtype="$3"
  local output_path="$4"
  local onnx_hash="${5:-}"

  if [[ ! -f "$output_path" ]]; then
    echo "ERROR: cannot cache missing RKNN output: $output_path" >&2
    return 1
  fi

  if [[ -z "$onnx_hash" ]]; then
    onnx_hash="$(_rknn_compute_sha256 "$onnx_path")" || return 1
  fi

  local cache_dir cached_rknn meta_path
  cache_dir="$(_rknn_cache_dir)"
  cached_rknn="$(rknn_cache_artifact_path "$onnx_hash" "$platform" "$dtype")"
  meta_path="$(rknn_cache_meta_path "$onnx_hash" "$platform" "$dtype")"

  mkdir -p "$cache_dir"
  cp -f "$output_path" "$cached_rknn"

  local onnx_rel output_rel cached_at onnx_size
  onnx_rel="${onnx_path#$AI_LIBRARY/}"
  output_rel="${output_path#$AI_LIBRARY/}"
  cached_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  onnx_size="$(wc -c < "$onnx_path" | tr -d ' ')"

  cat > "$meta_path" <<EOF
{
  "onnx_path": "${onnx_rel}",
  "onnx_sha256": "${onnx_hash}",
  "onnx_size_bytes": ${onnx_size},
  "platform": "${platform}",
  "dtype": "${dtype}",
  "output_rknn": "${output_rel}",
  "cached_rknn": "${cached_rknn#$AI_LIBRARY/}",
  "cached_at": "${cached_at}"
}
EOF

  echo "make rknn: cached onnx_sha256=${onnx_hash:0:12}... -> ${cached_rknn#$AI_LIBRARY/}" >&2
}
