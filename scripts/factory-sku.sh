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
FACTORY_OEM_OUT_DIR="$ROOT/oem/out/$OEM_ID"
FACTORY_OEM_IMG="$FACTORY_OEM_OUT_DIR/oem.img"

# Early loader: prefer rkbin boot_merger OUTPUT basename (exactly one match),
# optional FACTORY_SPL_LOADER= basename pin, then transitional MiniLoaderAll.bin.
_factory_sku_resolve_loader() {
  local dir="$1" pinned cand matches=()
  if [[ -n "${FACTORY_SPL_LOADER:-}" ]]; then
    pinned="$dir/$FACTORY_SPL_LOADER"
    [[ -r "$pinned" ]] || _factory_sku_die "FACTORY_SPL_LOADER=$FACTORY_SPL_LOADER not readable under $dir"
    echo "$pinned"
    return 0
  fi
  shopt -s nullglob
  matches=("$dir"/rk356x_spl_loader_*.bin "$dir"/rk3562_spl_loader_*.bin)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 1 ]]; then
    echo "${matches[0]}"
    return 0
  fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    _factory_sku_die "multiple *_spl_loader_*.bin under $dir — keep exactly one or set FACTORY_SPL_LOADER=basename"
  fi
  cand="$dir/MiniLoaderAll.bin"
  [[ -r "$cand" ]] || _factory_sku_die "missing early loader under $dir (expected rk356x_spl_loader_*.bin / rk3562_spl_loader_*.bin or MiniLoaderAll.bin)"
  echo "$cand"
}

FACTORY_LOADER_BIN="$(_factory_sku_resolve_loader "$FACTORY_UBOOT_DIR")"
FACTORY_LOADER_BASENAME="$(basename "$FACTORY_LOADER_BIN")"

# Per-APP factory output (rootfs is product-specific; boot FITs stay shared).
if [[ -z "${APP_FIRMWARE_DIR:-}" ]]; then
	# shellcheck source=app-select.sh
	source "$ROOT/scripts/app-select.sh"
	app_select_resolve
fi
FACTORY_OUT_DIR="$APP_FIRMWARE_DIR/$FACTORY_SKU"
FACTORY_IMG="$FACTORY_OUT_DIR/factory.img"

factory_sku_require_uboot() {
  [[ -r "$FACTORY_UBOOT_IMG" ]] || _factory_sku_die "missing $FACTORY_UBOOT_IMG (UBOOT_ID=$UBOOT_ID)"
  [[ -r "$FACTORY_LOADER_BIN" ]] || _factory_sku_die "missing $FACTORY_LOADER_BIN (UBOOT_ID=$UBOOT_ID)"
}

factory_sku_require_oem() {
  [[ -r "$FACTORY_OEM_IMG" ]] || _factory_sku_die "missing $FACTORY_OEM_IMG — run: FACTORY_SKU=$FACTORY_SKU make build-oem"
}

factory_sku_print() {
  echo "FACTORY_SKU=$FACTORY_SKU UBOOT_ID=$UBOOT_ID OEM_ID=$OEM_ID APP=${APP:-lws_hmi}"
  echo "  uboot:  $FACTORY_UBOOT_IMG"
  echo "  loader: $FACTORY_LOADER_BIN"
  echo "  oem:    $FACTORY_OEM_IMG"
  echo "  out:    $FACTORY_IMG"
}

# OEM-only builds (e.g. build-emulator → OEM_ID=sim-virt): do not imply factory.img.
factory_sku_print_oem() {
  echo "OEM_ID=$OEM_ID → $FACTORY_OEM_IMG"
  if [[ "$OEM_ID" != "${_default_oem}" ]]; then
    echo "  (FACTORY_SKU=$FACTORY_SKU default pack is ${_default_oem}; this build overrides OEM_ID)"
  fi
}

export FACTORY_SKU UBOOT_ID OEM_ID
export FACTORY_UBOOT_DIR FACTORY_UBOOT_IMG FACTORY_LOADER_BIN FACTORY_LOADER_BASENAME
export FACTORY_OEM_OUT_DIR FACTORY_OEM_IMG
export FACTORY_OUT_DIR FACTORY_IMG
