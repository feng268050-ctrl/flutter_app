#!/bin/sh
# Compose OEM pack into /run/hmi before HMI starts.
# Missing or invalid /oem MUST fail — no rootfs fallback.
set -eu

OEM_ROOT="${OEM_ROOT:-/oem}"
RUN_HMI="${RUN_HMI:-/run/hmi}"
VAR_HAL="${VAR_HAL:-/var/lib/hal}"
PRODUCT_INI="$VAR_HAL/product.ini"

log() { echo "oem-compose: $*"; }
warn() { echo "oem-compose: WARNING: $*" >&2; }
die() { echo "oem-compose: ERROR: $*" >&2; exit 1; }

ensure_oem_mount() {
	local dev="/dev/block/by-name/oem"
	local img="${OEM_IMG:-}"
	mkdir -p "$OEM_ROOT"
	if mountpoint -q "$OEM_ROOT" 2>/dev/null; then
		return 0
	fi
	# Directory mode (unpacked pack / bind mount): already has manifest.
	if [ -f "$OEM_ROOT/manifest.json" ]; then
		log "using directory OEM_ROOT=$OEM_ROOT (no partition mount)"
		return 0
	fi
	# Optional loop-mount of oem.img (virt guest / host probe).
	if [ -n "$img" ] && [ -f "$img" ]; then
		mount -t ext4 -o loop,noatime "$img" "$OEM_ROOT" 2>/dev/null \
			|| mount -o loop,noatime "$img" "$OEM_ROOT" 2>/dev/null \
			|| die "loop-mount $img -> $OEM_ROOT failed"
		log "loop-mounted $img -> $OEM_ROOT"
		return 0
	fi
	# P3.2 QEMU: second virtio disk is oem.img
	if [ -b /dev/vdb ]; then
		mount -t ext4 -o noatime /dev/vdb "$OEM_ROOT" 2>/dev/null \
			|| mount -o noatime /dev/vdb "$OEM_ROOT" 2>/dev/null \
			|| die "mount /dev/vdb -> $OEM_ROOT failed"
		log "mounted emulator oem disk /dev/vdb -> $OEM_ROOT"
		return 0
	fi
	[ -b "$dev" ] || die "oem partition missing ($dev) — flash/upgrade oem.img (or set OEM_ROOT / OEM_IMG)"
	mount -t ext4 -o noatime "$dev" "$OEM_ROOT" 2>/dev/null \
		|| mount -o noatime "$dev" "$OEM_ROOT" 2>/dev/null \
		|| die "mount $dev -> $OEM_ROOT failed"
}

# Merge OEM seed into runtime product.ini.
# brand/model/sn: always from OEM when present in seed (SKU identity).
# Other keys: fill only when runtime key is absent or blank (preserve operator).
merge_product_ini() {
	local seed="$1"
	local key val cur line force
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
		force=0
		case "$key" in
		brand | model | sn) force=1 ;;
		esac
		cur="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$PRODUCT_INI" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)"
		cur="$(printf '%s' "$cur" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		if [ "$force" -eq 0 ] && [ -n "$cur" ]; then
			continue
		fi
		if [ "$force" -eq 1 ] && [ "$cur" = "$val" ]; then
			continue
		fi
		# Drop existing key then append seed value.
		tmp="$(mktemp "${PRODUCT_INI}.XXXXXX")"
		grep -vE "^[[:space:]]*${key}[[:space:]]*=" "$PRODUCT_INI" >"$tmp" 2>/dev/null || true
		printf '%s=%s\n' "$key" "$val" >>"$tmp"
		mv -f "$tmp" "$PRODUCT_INI"
		if [ "$force" -eq 1 ]; then
			log "applied OEM identity $key from seed"
		else
			log "filled empty $key from OEM seed"
		fi
	done <"$seed"
}

write_screen_env() {
	local screen_json="$1"
	local orient width height
	orient="$(sed -n 's/.*"default_orientation"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$screen_json" | head -1)"
	width="$(sed -n 's/.*"width"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	height="$(sed -n 's/.*"height"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	[ -n "$orient" ] || die "screen.json missing default_orientation ($screen_json)"
	{
		echo "SCREEN_DEFAULT_ORIENTATION=$orient"
		echo "SCREEN_WIDTH=${width:-}"
		echo "SCREEN_HEIGHT=${height:-}"
	} >"$RUN_HMI/screen.env"
}

compose_from_root() {
	local root="$1"
	local manifest board_path screen_path board_id screen_id pack_id
	local board_profile screen_json product_seed
	local wifi_modem bt_modem usb_otg

	manifest="$root/manifest.json"
	[ -f "$manifest" ] || die "missing $manifest"

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

	wifi_modem="$(sed -n 's/.*"wifi_modem"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$board_profile" | head -1)"
	bt_modem="$(sed -n 's/.*"bt_modem"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$board_profile" | head -1)"
	usb_otg="$(sed -n 's/.*"usb_otg_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$board_profile" | head -1)"

	mkdir -p "$RUN_HMI"
	cp -f "$board_profile" "$RUN_HMI/board_profile.json"
	{
		echo "BOARD_ID=${board_id:-}"
		echo "SCREEN_ID=${screen_id:-}"
		echo "PACK_ID=${pack_id:-}"
		echo "OEM_BOARD_ROOT=$root/$board_path"
		echo "OEM_SCREEN_ROOT=$root/$screen_path"
		echo "OEM_ROOT=$root"
		echo "OEM_SOURCE=partition"
		echo "WIFI_MODEM_HELPER=${wifi_modem:-}"
		echo "BT_MODEM_HELPER=${bt_modem:-}"
		echo "USB_OTG_MODE_HELPER=${usb_otg:-}"
	} >"$RUN_HMI/oem.env"
	write_screen_env "$screen_json"
	merge_product_ini "$product_seed"

	gpio_sim="$(sed -n 's/.*"gpio_sim_leds"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$board_profile" | head -1)"
	if [ -n "$gpio_sim" ] && [ -x "$gpio_sim" ]; then
		"$gpio_sim" || warn "gpio_sim_leds helper failed"
	fi

	log "composed pack=${pack_id:-?} board=${board_id:-?} screen=${screen_id:-?} source=partition"
	return 0
}

ensure_oem_mount

[ -f "$OEM_ROOT/manifest.json" ] || die "no OEM manifest at $OEM_ROOT/manifest.json — build-oem + upgrade OEM (no rootfs fallback)"
compose_from_root "$OEM_ROOT"
exit 0
