#!/bin/sh
# Read product identity from Rockchip Vendor Storage or provision/identity.env.
# Usage:
#   read-product-identity.sh              # print brand / model / sn (one per line, labeled)
#   read-product-identity.sh brand|model|sn
# Empty field → empty string (caller applies chip-ID fallback for sn).
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"
PROVISION_IDENTITY="${PROVISION_IDENTITY:-/mnt/provision/identity.env}"

die() { echo "read-product-identity: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_SN_NAME:=VENDOR_SN_ID}"
: "${VENDOR_BRAND_NAME:=VENDOR_CUSTOM_ID_14}"
: "${VENDOR_MODEL_NAME:=VENDOR_CUSTOM_ID_15}"

read_id() {
	local name="$1"
	local tmp out
	[ -x "$VENDOR_STORAGE_BIN" ] || return 0
	[ -e /dev/vendor_storage ] || return 0
	tmp="$(mktemp)"
	if ! "$VENDOR_STORAGE_BIN" -r "$name" -t file -i "$tmp" >/dev/null 2>&1; then
		rm -f "$tmp"
		return 0
	fi
	out="$(tr -d '\000' <"$tmp" | tr -d '\r' | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')"
	rm -f "$tmp"
	printf '%s' "$out"
}

read_stub_field() {
	local field="$1"
	local file="$2"
	local line key val
	[ -r "$file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		line="$(printf '%s' "$line" | tr -d '\r')"
		case "$line" in
		'' | \#*) continue ;;
		esac
		key="${line%%=*}"
		val="${line#*=}"
		key="$(printf '%s' "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
		if [ "$key" = "$field" ]; then
			printf '%s' "$val"
			return 0
		fi
	done <"$file"
}

is_emulator_board() {
	grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null && return 0
	[ -d /sys/firmware/qemu_fw_cfg ] && return 0
	if [ -f /oem/manifest.json ]; then
		case "$(sed -n 's/.*"board_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)" in
		sim) return 0 ;;
		esac
	fi
	return 1
}

# Dev-only: autogen per provision.img when sim/emulator has no identity file yet.
maybe_autogen_provision_identity() {
	local chip hash sn
	[ -e /dev/vendor_storage ] && return 0
	is_emulator_board || return 0
	[ -d /mnt/provision ] || return 0
	if [ -f "$PROVISION_IDENTITY" ] && [ -n "$(read_stub_field sn "$PROVISION_IDENTITY")" ]; then
		return 0
	fi
	chip="$(/usr/libexec/board/read-device-serial.sh --chip-id 2>/dev/null || true)"
	hash="$(printf '%s' "${chip:-sim}" | cksum | awk '{print $1}')"
	sn="SIM$(printf '%06d' $((hash % 1000000)))"
	mkdir -p "$(dirname "$PROVISION_IDENTITY")"
	{
		echo "brand=LaserCyber"
		echo "model=L1 Pro"
		echo "sn=$sn"
	} >"$PROVISION_IDENTITY"
	chmod 0644 "$PROVISION_IDENTITY" 2>/dev/null || true
	log_autogen() { echo "read-product-identity: autogen $PROVISION_IDENTITY sn=$sn" >&2; }
	log_autogen
}

resolve_provision_identity_file() {
	if [ -r "$PROVISION_IDENTITY" ]; then
		printf '%s' "$PROVISION_IDENTITY"
		return 0
	fi
	maybe_autogen_provision_identity
	[ -r "$PROVISION_IDENTITY" ] && printf '%s' "$PROVISION_IDENTITY"
}

read_field() {
	local field="$1"
	local vs_name="$2"
	local stub out
	if [ -e /dev/vendor_storage ]; then
		read_id "$vs_name"
		return 0
	fi
	stub="$(resolve_provision_identity_file 2>/dev/null || true)"
	[ -n "$stub" ] || return 0
	out="$(read_stub_field "$field" "$stub")"
	printf '%s' "$out"
}

field="${1:-}"
case "$field" in
'')
	printf 'brand=%s\n' "$(read_field brand "$VENDOR_BRAND_NAME")"
	printf 'model=%s\n' "$(read_field model "$VENDOR_MODEL_NAME")"
	printf 'sn=%s\n' "$(read_field sn "$VENDOR_SN_NAME")"
	;;
brand)
	printf '%s\n' "$(read_field brand "$VENDOR_BRAND_NAME")"
	;;
model)
	printf '%s\n' "$(read_field model "$VENDOR_MODEL_NAME")"
	;;
sn)
	printf '%s\n' "$(read_field sn "$VENDOR_SN_NAME")"
	;;
*)
	die "usage: $0 [brand|model|sn]"
	;;
esac
