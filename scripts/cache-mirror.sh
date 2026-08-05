#!/usr/bin/env bash
# Shared NAS cache for large artifacts under .cache/ (not in git).
#
# Layout on NAS_CACHE_ROOT (NFS/SMB mount):
#   flutter-engine/<version>/flutter-<version>.tar.gz
#   flutter-engine/<version>/flutter-<version>.tar.gz.sha256
#
# Set in .env (see .env.example):
#   NAS_CACHE_ROOT=/Volumes/nas/lws-hmi-cache
#   NAS_READ_ONLY=0   # 1 = never write back to NAS (default 0)
set -euo pipefail

cache_mirror_load_env() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  if [[ -f "$root/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$root/.env"
    set +a
  fi
}

cache_mirror_enabled() {
  [[ -n "${NAS_CACHE_ROOT:-}" && -d "${NAS_CACHE_ROOT}" ]]
}

cache_mirror_relpath() {
  printf '%s/%s/%s' "$1" "$2" "$3"
}

cache_mirror_local_path() {
  [[ -n "${NAS_CACHE_ROOT:-}" ]] || return 1
  echo "${NAS_CACHE_ROOT%/}/$(cache_mirror_relpath "$1" "$2" "$3")"
}

cache_mirror_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

cache_mirror_verify() {
  local file="$1" expected="$2"
  [[ "$(cache_mirror_sha256 "$file")" == "$expected" ]]
}

# cache_mirror_fetch <category> <version> <filename> <dest>
cache_mirror_fetch() {
  local category="$1" version="$2" filename="$3" dest="$4"
  local relpath="${category}/${version}/${filename}"
  local sha_name="${filename}.sha256"

  mkdir -p "$(dirname "$dest")"

  [[ -n "${NAS_CACHE_ROOT:-}" ]] || return 1
  local src="${NAS_CACHE_ROOT%/}/${relpath}"
  local sha_src="${NAS_CACHE_ROOT%/}/${category}/${version}/${sha_name}"
  if [[ -f "$src" ]]; then
    echo "cache-mirror: copy ${src} → ${dest}"
    cp -f "$src" "$dest"
    if [[ -f "$sha_src" ]]; then
      local expected
      expected="$(tr -d '[:space:]' <"$sha_src")"
      if ! cache_mirror_verify "$dest" "$expected"; then
        echo "ERROR: cache-mirror: sha256 mismatch for ${src}" >&2
        rm -f "$dest"
        return 1
      fi
      echo "cache-mirror: sha256 ok"
    fi
    return 0
  fi

  return 1
}

# cache_mirror_publish <category> <version> <filename> <src>
cache_mirror_publish() {
  local category="$1" version="$2" filename="$3" src="$4"

  [[ "${NAS_READ_ONLY:-0}" == "1" ]] && return 0
  [[ -n "${NAS_CACHE_ROOT:-}" ]] || return 0
  [[ -d "${NAS_CACHE_ROOT}" ]] || {
    echo "cache-mirror: skip publish (not a directory: ${NAS_CACHE_ROOT})" >&2
    return 0
  }
  [[ -w "${NAS_CACHE_ROOT}" ]] || {
    echo "cache-mirror: skip publish (not writable: ${NAS_CACHE_ROOT})" >&2
    return 0
  }

  local dest_dir="${NAS_CACHE_ROOT%/}/${category}/${version}"
  local dest="${dest_dir}/${filename}"
  mkdir -p "$dest_dir"
  if [[ -f "$dest" ]] && cache_mirror_verify "$dest" "$(cache_mirror_sha256 "$src")"; then
    echo "cache-mirror: already on NAS ${dest}"
    return 0
  fi
  echo "cache-mirror: publish ${src} → ${dest}"
  cp -f "$src" "$dest"
  cache_mirror_sha256 "$dest" >"${dest}.sha256"
}
