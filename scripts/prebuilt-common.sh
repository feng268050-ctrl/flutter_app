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

# Resolve Buildroot O= directory: buildroot/output/<RK_BUILDROOT_CFG>/.
# BASE_CFG (e.g. rk3566_rk3568_lws_hmi) is not the output folder name; SDK uses
# RK_BUILDROOT_CFG (e.g. rockchip_rk3566_rk3568_lws_hmi). Override with BR_OUTPUT.
resolve_br_output_dir() {
  local sdk="$1"
  local out_base="$sdk/buildroot/output"
  local profile dir cfg="$sdk/output/.config"

  if [[ -n "${BR_OUTPUT:-}" ]]; then
    echo "$out_base/$BR_OUTPUT"
    return 0
  fi

  if [[ -r "$cfg" ]]; then
    profile="$(sed -n 's/^RK_BUILDROOT_CFG="\(.*\)"$/\1/p' "$cfg")"
    local base
    base="$(sed -n 's/^RK_BUILDROOT_BASE_CFG="\(.*\)"$/\1/p' "$cfg")"
    if [[ -n "$profile" && "$profile" == *'${RK_BUILDROOT_BASE_CFG}'* && -n "$base" ]]; then
      profile="${profile/\$\{RK_BUILDROOT_BASE_CFG\}/$base}"
    fi
    if [[ -z "$profile" && -n "$base" ]]; then
      profile="rockchip_${base}"
    fi
  fi
  profile="${profile:-rockchip_rk3566_rk3568_lws_hmi}"

  if [[ -d "$out_base/$profile" ]]; then
    echo "$out_base/$profile"
    return 0
  fi

  for dir in \
    "$out_base/rockchip_rk3566_rk3568_lws_hmi" \
    "$out_base"/rockchip_*lws_hmi* \
    "$out_base"/rockchip_rk3566_*; do
    [[ -d "$dir/target" ]] || continue
    echo "$dir"
    return 0
  done

  echo "$out_base/$profile"
}

resolve_br_target() {
  echo "$(resolve_br_output_dir "$1")/target"
}
