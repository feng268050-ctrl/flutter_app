#!/bin/sh
# Read product identity from Rockchip Vendor Storage.
# Usage:
#   read-product-identity.sh              # print brand / model / sn (one per line, labeled)
#   read-product-identity.sh brand|model|sn
# Empty / missing Vendor Storage field → empty string (caller applies chip-ID fallback for sn).
#
# Emulator stub: when /dev/vendor_storage is absent, optionally read OEM
# identity.env (see oem/boards/sim/identity.env). Never used when the VS
# device node exists — empty VS fields stay empty until write-identity.
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"
# Override path for tests; default search: /oem/identity.env then /oem/boards/*/identity.env
IDENTITY_STUB="${IDENTITY_STUB:-}"

die() { echo "read-product-identity: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_SN_NAME:=VENDOR_SN_ID}"
: "${VENDOR_BRAND_NAME:=VENDOR_CUSTOM_ID_14}"
: "${VENDOR_MODEL_NAME:=VENDOR_CUSTOM_ID_15}"

# Read one ID into stdout (trimmed ASCII, no trailing NULs). Fail → empty (exit 0).
read_id() {
	local name="$1"
	local tmp out
	[ -x "$VENDOR_STORAGE_BIN" ] || return 0
	[ -e /dev/vendor_storage ] || return 0
	tmp="$(mktemp)"
	# stderr discarded: missing ID / open fail → empty field
	if ! "$VENDOR_STORAGE_BIN" -r "$name" -t file -i "$tmp" >/dev/null 2>&1; then
		rm -f "$tmp"
		return 0
	fi
	# Strip NULs and trailing whitespace/newlines; keep printable content.
	out="$(tr -d '\000' <"$tmp" | tr -d '\r' | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')"
	rm -f "$tmp"
	printf '%s' "$out"
}

# Parse brand|model|sn from a flat key=value identity.env (comments/blanks ignored).
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

resolve_stub_file() {
	local f
	if [ -n "$IDENTITY_STUB" ] && [ -r "$IDENTITY_STUB" ]; then
		printf '%s' "$IDENTITY_STUB"
		return 0
	fi
	if [ -r /oem/identity.env ]; then
		printf '%s' /oem/identity.env
		return 0
	fi
	for f in /oem/boards/*/identity.env; do
		[ -r "$f" ] || continue
		printf '%s' "$f"
		return 0
	done
	return 1
}

# Prefer Vendor Storage when the device node exists; else OEM emulator stub.
read_field() {
	local field="$1"
	local vs_name="$2"
	local stub out
	if [ -e /dev/vendor_storage ]; then
		read_id "$vs_name"
		return 0
	fi
	stub="$(resolve_stub_file 2>/dev/null || true)"
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
