#!/usr/bin/env bash
# Populate SDK innohi_board/ from vendor innohi/rootfs (gitignored upstream).
# Innohi mk-rootfs.sh and post-wifibt.sh expect this tree; SDK ships only innohi/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"

INNOHI="$SDK/innohi/rootfs"
BOARD="$SDK/innohi_board"
FW_SRC="$INNOHI/system/etc/firmware"
FW_DST="$BOARD/rootfs_board/system/etc/firmware"

if [[ ! -d "$INNOHI" ]]; then
  echo "WARNING: sync-innohi-board: missing $INNOHI — skip" >&2
  exit 0
fi

mkdir -p "$BOARD"

echo "sync-innohi-board: rootfs → $BOARD/rootfs/"
if command -v rsync >/dev/null 2>&1; then
  rsync -a "$INNOHI/" "$BOARD/rootfs/"
else
  mkdir -p "$BOARD/rootfs"
  cp -a "$INNOHI/." "$BOARD/rootfs/"
fi

if [[ -d "$FW_SRC" ]]; then
  echo "sync-innohi-board: firmware → $FW_DST/"
  mkdir -p "$FW_DST"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$FW_SRC/" "$FW_DST/"
  else
    cp -a "$FW_SRC/." "$FW_DST/"
  fi
else
  echo "WARNING: sync-innohi-board: no firmware under $FW_SRC" >&2
fi

echo "sync-innohi-board: done"
