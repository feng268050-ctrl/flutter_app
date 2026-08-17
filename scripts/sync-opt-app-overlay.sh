#!/usr/bin/env bash
# Copy app/<APP>/build/bundle/release → SDK Buildroot rootfs-overlay/opt/<name>.
# Called from ensure-rootfs-apps (make build-rootfs), not from build-app or apply-overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
# shellcheck source=platform-paths.sh
source "$ROOT/scripts/platform-paths.sh"
platform_paths_init "$ROOT" "$SDK"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"

sync_app_bundle() {
  local app_id="$1"
  local opt_name="$2"
  local src
  src="$(app_select_bundle_for "$app_id")" || return 1
  if ! app_select_bundle_has_release "$src"; then
    echo "sync-opt-app: skip opt/$opt_name (no bundle at $src)"
    return 0
  fi
  if [[ ! -d "$BR_COMMON" ]]; then
    echo "WARNING: SDK Buildroot common dir missing ($BR_COMMON); skip sync opt/$opt_name" >&2
    return 0
  fi
  mkdir -p "$BR_OVERLAY_ROOT/opt/$opt_name"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$BR_OVERLAY_ROOT/opt/$opt_name/"
  else
    rm -rf "$BR_OVERLAY_ROOT/opt/$opt_name"
    mkdir -p "$BR_OVERLAY_ROOT/opt/$opt_name"
    cp -a "$src/." "$BR_OVERLAY_ROOT/opt/$opt_name/"
  fi
  echo "sync-opt-app: $src → $BR_OVERLAY_ROOT/opt/$opt_name"
}

usage() {
  echo "usage: $0 [--product | <app-id>…]" >&2
  echo "  --product     sync primary APP (*_hmi → opt/hmi) + os_settings when built (build-rootfs)" >&2
  echo "  <app-id>…     sync each app id to its opt name (e.g. lws_hmi os_settings)" >&2
  exit 2
}

if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
  usage
fi

if [[ "${1:-}" == --product ]]; then
  app_select_resolve
  if app_select_is_hmi "$APP"; then
    sync_app_bundle "$APP" hmi
  fi
  if app_select_os_settings_exists; then
    sync_app_bundle os_settings os_settings
  fi
  exit 0
fi

if [[ $# -gt 0 ]]; then
  for app_id in "$@"; do
    opt_name="$(app_select_opt_name "$app_id")"
    sync_app_bundle "$app_id" "$opt_name"
  done
  exit 0
fi

echo "ERROR: $0 requires --product or explicit app id(s)" >&2
exit 1
