#!/bin/sh
# Compose OEM pack into /run/hmi before HMI starts.
# Migration: missing /oem falls back to /usr/share/hmi/oem-fallback (deprecated).
set -eu

OEM_ROOT="${OEM_ROOT:-/oem}"
RUN_HMI="${RUN_HMI:-/run/hmi}"
FALLBACK_ROOT="${OEM_FALLBACK_ROOT:-/usr/share/hmi/oem-fallback}"
VAR_HAL="${VAR_HAL:-/var/lib/hal}"
PRODUCT_INI="$VAR_HAL/product.ini"

log() { echo "oem-compose: $*"; }
warn() { echo "oem-compose: WARNING: $*" >&2; }
die() { echo "oem-compose: ERROR: $*" >&2; exit 1; }

ensure_oem_mount() {
	local dev="/dev/block/by-name/oem"
	mkdir -p "$OEM_ROOT"
	if mountpoint -q "$OEM_ROOT" 2>/dev/null; then
		return 0
	fi
	if [ -b "$dev" ]; then
		mount -t ext4 -o noatime "$dev" "$OEM_ROOT" 2>/dev/null \
			|| mount -o noatime "$dev" "$OEM_ROOT" 2>/dev/null \
			|| warn "mount $dev -> $OEM_ROOT failed"
	fi
}

# Merge seed keys into runtime product.ini; never overwrite non-empty values.
merge_product_ini() {
	local seed="$1"
	local key val cur line
	[ -f "$seed" ] || return 0
	mkdir -p "$VAR_HAL"
	if [ ! -f "$PRODUCT_INI" ]; then
		cp -f "$seed" "$PRODUCT_INI"
		log "seeded $PRODUCT_INI from OEM"
		return 0
	fi
	while IFS= read -r line || [ -n "$line" ]; do
		case "$line" in
		'' | \#*) continue ;;
		esac
		key="${line%%=*}"
		val="${line#*=}"
		key="$(printf '%s' "$key" | tr -d '[:space:]')"
		[ -n "$key" ] || continue
		cur="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$PRODUCT_INI" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)"
		cur="$(printf '%s' "$cur" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		if [ -n "$cur" ]; then
			continue
		fi
		# Drop blank/absent key then append seed value.
		tmp="$(mktemp "${PRODUCT_INI}.XXXXXX")"
		grep -vE "^[[:space:]]*${key}[[:space:]]*=" "$PRODUCT_INI" >"$tmp" 2>/dev/null || true
		printf '%s=%s\n' "$key" "$val" >>"$tmp"
		mv -f "$tmp" "$PRODUCT_INI"
		log "filled empty $key from OEM seed"
	done <"$seed"
}

write_screen_env() {
	local screen_json="$1"
	local orient width height
	orient="$(sed -n 's/.*"default_orientation"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$screen_json" | head -1)"
	width="$(sed -n 's/.*"width"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	height="$(sed -n 's/.*"height"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	{
		echo "SCREEN_DEFAULT_ORIENTATION=${orient:-}"
		echo "SCREEN_WIDTH=${width:-}"
		echo "SCREEN_HEIGHT=${height:-}"
	} >"$RUN_HMI/screen.env"
}

compose_from_root() {
	local root="$1"
	local migrate="$2"
	local manifest board_path screen_path board_id screen_id pack_id
	local board_profile screen_json product_seed

	manifest="$root/manifest.json"
	[ -f "$manifest" ] || return 1

	board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)"
	screen_path="$(sed -n 's/.*"screen_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)"
	board_id="$(sed -n 's/.*"board_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)"
	screen_id="$(sed -n 's/.*"screen_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)"
	pack_id="$(sed -n 's/.*"pack_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$manifest" | head -1)"

	[ -n "$board_path" ] && [ -n "$screen_path" ] || die "manifest missing board_path/screen_path"
	[ -d "$root/$board_path" ] || die "board_path missing: $root/$board_path"
	[ -d "$root/$screen_path" ] || die "screen_path missing: $root/$screen_path"

	board_profile="$root/$board_path/board_profile.json"
	screen_json="$root/$screen_path/screen.json"
	product_seed="$root/$board_path/product.ini"
	[ -f "$board_profile" ] || die "missing $board_profile"
	[ -f "$screen_json" ] || die "missing $screen_json"

	mkdir -p "$RUN_HMI"
	cp -f "$board_profile" "$RUN_HMI/board_profile.json"
	{
		echo "BOARD_ID=${board_id:-}"
		echo "SCREEN_ID=${screen_id:-}"
		echo "PACK_ID=${pack_id:-}"
		echo "OEM_BOARD_ROOT=$root/$board_path"
		echo "OEM_SCREEN_ROOT=$root/$screen_path"
		echo "OEM_ROOT=$root"
		if [ "$migrate" = "1" ]; then
			echo "OEM_MIGRATE_FALLBACK=1"
		fi
	} >"$RUN_HMI/oem.env"
	write_screen_env "$screen_json"
	merge_product_ini "$product_seed"

	if [ "$migrate" = "1" ]; then
		warn "using deprecated rootfs fallback at $root — flash/upgrade oem.img"
	else
		log "composed pack=${pack_id:-?} board=${board_id:-?} screen=${screen_id:-?}"
	fi
	return 0
}

ensure_oem_mount

# Prefer real OEM pack; invalid pack fails hard (no silent board swap).
if [ -f "$OEM_ROOT/manifest.json" ]; then
	compose_from_root "$OEM_ROOT" 0
	exit 0
fi

# Migration window only: rootfs-bundled ynh960 default.
if [ -f "$FALLBACK_ROOT/manifest.json" ]; then
	warn "OEM pack missing at $OEM_ROOT — DEPRECATED fallback $FALLBACK_ROOT"
	compose_from_root "$FALLBACK_ROOT" 1
	exit 0
fi

die "no OEM manifest at $OEM_ROOT and no fallback at $FALLBACK_ROOT"
