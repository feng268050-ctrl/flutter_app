#!/usr/bin/env bash
# Copy exported prebuilt runtime trees into Buildroot fs-overlay paths (Phase 4).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=platform-paths.sh
source "$ROOT/scripts/platform-paths.sh"
platform_paths_init "$ROOT" "${SDK_DIR:-$ROOT/linux-sdk}"

BR_BOARD_REPO="$LWS_OVERLAY_BOARD"
SDK_DIR="${SDK_DIR:-$ROOT/linux-sdk}"
SDK_BR_BOARD="$BR_COMMON"
GST_SRC="$ROOT/prebuilt/gstreamer/target"
PLAT_SRC="$ROOT/prebuilt/platform-packages/target"
GST_DEST="$BR_BOARD_REPO/lws-hmi-prebuilt-gstreamer"
PLAT_DEST="$BR_BOARD_REPO/lws-hmi-prebuilt-platform"

sync_tree() {
  local label="$1" src="$2" dest="$3"
  if ! prebuilt_ready "$src"; then
    echo "sync-prebuilt-overlays: skip $label (no $src/.lws-prebuilt)"
    return 0
  fi
  if [[ ! -d "$src/usr" ]]; then
    echo "ERROR: $src missing usr/ — run: make build-gstreamer or make build-platform-packages" >&2
    return 1
  fi
  mkdir -p "$dest"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$dest/"
  else
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -a "$src/." "$dest/"
  fi
  if [[ -d "$(dirname "$SDK_BR_BOARD")" ]]; then
    local sdk_dest="$SDK_BR_BOARD/$(basename "$dest")"
    mkdir -p "$sdk_dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete "$dest/" "$sdk_dest/"
    else
      rm -rf "$sdk_dest"
      mkdir -p "$sdk_dest"
      cp -a "$dest/." "$sdk_dest/"
    fi
  fi
  echo "sync-prebuilt-overlays: $label → $dest"
}

sync_tree "gstreamer" "$GST_SRC" "$GST_DEST"
sync_tree "platform-packages" "$PLAT_SRC" "$PLAT_DEST"
