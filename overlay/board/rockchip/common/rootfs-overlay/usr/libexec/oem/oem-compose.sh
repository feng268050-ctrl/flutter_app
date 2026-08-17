#!/bin/sh
# Compose OEM pack into /run/hmi before HMI starts.
# Missing or invalid /oem MUST fail — no rootfs fallback.
# Does NOT seed /var/lib/hal/properties.ini (operator: make set-prop).
set -eu

OEM_ROOT="${OEM_ROOT:-/oem}"
RUN_HMI="${RUN_HMI:-/run/hmi}"

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

seed_input_conf_from_pack() {
	local root="$1"
	local defaults="$root/input_defaults.json"
	local pref="${VAR_HAL:-/var/lib/hal}/input.conf"
	. /usr/libexec/board/paths.sh 2>/dev/null || true
	pref="${VAR_HAL:-/var/lib/hal}/input.conf"
	if [ -f "$pref" ]; then
		return 0
	fi
	if [ ! -f "$defaults" ]; then
		return 0
	fi
	kb=1
	mouse=1
	if grep -qE '"physical_keyboard_enabled"[[:space:]]*:[[:space:]]*false' "$defaults" 2>/dev/null; then
		kb=0
	fi
	if grep -qE '"physical_mouse_enabled"[[:space:]]*:[[:space:]]*false' "$defaults" 2>/dev/null; then
		mouse=0
	fi
	mkdir -p "$(dirname "$pref")"
	{
		echo "physical_keyboard_enabled=$kb"
		echo "physical_mouse_enabled=$mouse"
	} >"$pref"
	log "seeded $pref from pack input_defaults (keyboard=$kb mouse=$mouse)"
}

write_screen_env() {
	local screen_json="$1"
	local orient width height ui_scale ui_scale_valid
	orient="$(sed -n 's/.*"default_orientation"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$screen_json" | head -1)"
	width="$(sed -n 's/.*"width"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	height="$(sed -n 's/.*"height"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$screen_json" | head -1)"
	ui_scale="$(sed -n 's/.*"default_ui_scale"[[:space:]]*:[[:space:]]*\([0-9.][0-9.]*\).*/\1/p' "$screen_json" | head -1)"
	[ -n "$orient" ] || die "screen.json missing default_orientation ($screen_json)"
	if [ -n "$ui_scale" ]; then
		ui_scale_valid="$(printf '%s' "$ui_scale" | awk '{
			if ($1+0 != $1 || $1 == "") { exit 1 }
			v=$1+0; if (v < 0.5) v=0.5; if (v > 2.0) v=2.0; printf "%.3f", v; exit 0
		}' 2>/dev/null || true)"
		if [ -z "$ui_scale_valid" ]; then
			warn "screen.json invalid default_ui_scale ($ui_scale) — omitted"
		fi
	else
		ui_scale_valid=""
	fi
	{
		echo "SCREEN_DEFAULT_ORIENTATION=$orient"
		echo "SCREEN_WIDTH=${width:-}"
		echo "SCREEN_HEIGHT=${height:-}"
		[ -n "$ui_scale_valid" ] && echo "SCREEN_DEFAULT_UI_SCALE=$ui_scale_valid"
	} >"$RUN_HMI/screen.env"
}

compose_from_root() {
	local root="$1"
	local manifest board_path screen_path board_id screen_id pack_id
	local board_profile screen_json
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

# Runtime board stamp for systemd ConditionPathExists (board-specific units).
	if [ -z "$board_id" ]; then
		die "manifest missing board_id"
	fi
	case "$board_id" in
	*[!A-Za-z0-9._-]*) die "invalid board_id '$board_id'" ;;
	esac
	printf '%s\n' "$board_id" >"$RUN_HMI/board_id"
	mkdir -p "$RUN_HMI/boards.d"
	rm -f "$RUN_HMI/boards.d"/* 2>/dev/null || true
	touch "$RUN_HMI/boards.d/$board_id"

	gpio_sim="$(sed -n 's/.*"gpio_sim_leds"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$board_profile" | head -1)"
	if [ -n "$gpio_sim" ] && [ -x "$gpio_sim" ]; then
		"$gpio_sim" || warn "gpio_sim_leds helper failed"
	fi

	seed_input_conf_from_pack "$root"

	log "composed pack=${pack_id:-?} board=${board_id:-?} screen=${screen_id:-?} source=partition"
	return 0
}

ensure_oem_mount

[ -f "$OEM_ROOT/manifest.json" ] || die "no OEM manifest at $OEM_ROOT/manifest.json — build-oem + upgrade OEM (no rootfs fallback)"
compose_from_root "$OEM_ROOT"
exit 0
