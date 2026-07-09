#!/usr/bin/env bash
# Shared helpers for git-tracked prebuilt/ artifacts vs gitignored .cache/ sources.
set -euo pipefail

prebuilt_root() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  echo "$root/prebuilt"
}

cache_root() {
  local root="${1:-}"
  if [[ -z "$root" ]]; then
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
  echo "$root/.cache"
}

# Write a single-line version stamp consumed by Buildroot .mk wildcard checks.
prebuilt_stamp() {
  local dir="$1"
  local version="$2"
  mkdir -p "$dir"
  printf '%s\n' "$version" > "$dir/.lws-prebuilt"
}

prebuilt_ready() {
  local dir="$1"
  [[ -f "$dir/.lws-prebuilt" ]]
}

# Copy built tree into prebuilt/, preserving permissions; write stamp last.
prebuilt_install_tree() {
  local src="$1"
  local dest="$2"
  local version="$3"
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --no-owner --no-group --no-perms --omit-dir-times "$src"/ "$dest"/
  else
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src"/. "$dest"/
  fi
  prebuilt_stamp "$dest" "$version"
}

read_version_file() {
  local file="$1"
  local fallback="${2:-}"
  if [[ -f "$file" ]]; then
    tr -d '[:space:]' < "$file"
    return 0
  fi
  echo "$fallback"
}
