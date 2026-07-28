#!/usr/bin/env bash
# Shared FACTORY_SKU → UBOOT_ID / OEM_ID / path resolution for build-oem, build-img, flash, upgrade.
# Source this file; do not execute. Sets:
#   FACTORY_SKU UBOOT_ID OEM_ID
#   FACTORY_UBOOT_DIR FACTORY_UBOOT_IMG FACTORY_LOADER_BIN
#   FACTORY_OEM_IMG FACTORY_OEM_OUT_DIR
#   FACTORY_OUT_DIR FACTORY_IMG
#
# Env overrides: FACTORY_SKU, UBOOT_ID, OEM_ID
# Default sku: ynh960-p800
set -euo pipefail

: "${ROOT:?factory-sku.sh requires ROOT}"

FACTORY_SKUS_TSV="${FACTORY_SKUS_TSV:-$ROOT/board/factory-skus.tsv}"
FACTORY_SKU="${FACTORY_SKU:-ynh960-p800}"

_factory_sku_die() {
  echo "ERROR: $*" >&2
  exit 1
}

_factory_sku_lookup() {
  local sku="$1" line uboot oem
  [[ -r "$FACTORY_SKUS_TSV" ]] || _factory_sku_die "missing SKU table: $FACTORY_SKUS_TSV"
  while IFS=$'\t' read -r line || [[ -n "$line" ]]; do
    case "$line" in
    '' | \#*) continue ;;
    esac
    # Allow spaces as separators too
    set -- $line
    [[ "${1:-}" == "$sku" ]] || continue
    uboot="${2:-}"
    oem="${3:-}"
    [[ -n "$uboot" && -n "$oem" ]] || _factory_sku_die "bad SKU row for $sku in $FACTORY_SKUS_TSV"
    echo "$uboot"$'\t'"$oem"
    return 0
  done <"$FACTORY_SKUS_TSV"
  return 1
}

_row="$(_factory_sku_lookup "$FACTORY_SKU")" || _factory_sku_die "unknown FACTORY_SKU=$FACTORY_SKU (see $FACTORY_SKUS_TSV)"
_default_uboot="${_row%%$'\t'*}"
_default_oem="${_row#*$'\t'}"

UBOOT_ID="${UBOOT_ID:-$_default_uboot}"
OEM_ID="${OEM_ID:-$_default_oem}"

FACTORY_UBOOT_DIR="$ROOT/prebuilt/bootloader/$UBOOT_ID"
FACTORY_UBOOT_IMG="$FACTORY_UBOOT_DIR/uboot.img"
FACTORY_LOADER_BIN="$FACTORY_UBOOT_DIR/MiniLoaderAll.bin"
FACTORY_OEM_OUT_DIR="$ROOT/oem/out/$OEM_ID"
FACTORY_OEM_IMG="$FACTORY_OEM_OUT_DIR/oem.img"
FACTORY_OUT_DIR="$ROOT/output/firmware/$FACTORY_SKU"
FACTORY_IMG="$FACTORY_OUT_DIR/factory.img"

factory_sku_require_uboot() {
  [[ -r "$FACTORY_UBOOT_IMG" ]] || _factory_sku_die "missing $FACTORY_UBOOT_IMG (UBOOT_ID=$UBOOT_ID)"
  [[ -r "$FACTORY_LOADER_BIN" ]] || _factory_sku_die "missing $FACTORY_LOADER_BIN (UBOOT_ID=$UBOOT_ID)"
}

factory_sku_require_oem() {
  [[ -r "$FACTORY_OEM_IMG" ]] || _factory_sku_die "missing $FACTORY_OEM_IMG — run: FACTORY_SKU=$FACTORY_SKU make build-oem"
}

factory_sku_print() {
  echo "FACTORY_SKU=$FACTORY_SKU UBOOT_ID=$UBOOT_ID OEM_ID=$OEM_ID"
  echo "  uboot: $FACTORY_UBOOT_IMG"
  echo "  oem:   $FACTORY_OEM_IMG"
  echo "  out:   $FACTORY_IMG"
}

# OEM-only builds (e.g. build-emulator → OEM_ID=sim_virt): do not imply factory.img.
factory_sku_print_oem() {
  echo "OEM_ID=$OEM_ID → $FACTORY_OEM_IMG"
  if [[ "$OEM_ID" != "${_default_oem}" ]]; then
    echo "  (FACTORY_SKU=$FACTORY_SKU default pack is ${_default_oem}; this build overrides OEM_ID)"
  fi
}

export FACTORY_SKU UBOOT_ID OEM_ID
export FACTORY_UBOOT_DIR FACTORY_UBOOT_IMG FACTORY_LOADER_BIN
export FACTORY_OEM_OUT_DIR FACTORY_OEM_IMG
export FACTORY_OUT_DIR FACTORY_IMG
