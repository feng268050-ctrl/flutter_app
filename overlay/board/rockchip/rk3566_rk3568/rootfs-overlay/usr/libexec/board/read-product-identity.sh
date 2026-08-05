#!/bin/sh
# Read product identity from Rockchip Vendor Storage.
# Usage:
#   read-product-identity.sh              # print brand / model / sn (one per line, labeled)
#   read-product-identity.sh brand|model|sn
# Empty / missing Vendor Storage field → empty string (caller applies chip-ID fallback for sn).
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"

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

field="${1:-}"
case "$field" in
'')
	printf 'brand=%s\n' "$(read_id "$VENDOR_BRAND_NAME")"
	printf 'model=%s\n' "$(read_id "$VENDOR_MODEL_NAME")"
	printf 'sn=%s\n' "$(read_id "$VENDOR_SN_NAME")"
	;;
brand)
	printf '%s\n' "$(read_id "$VENDOR_BRAND_NAME")"
	;;
model)
	printf '%s\n' "$(read_id "$VENDOR_MODEL_NAME")"
	;;
sn)
	printf '%s\n' "$(read_id "$VENDOR_SN_NAME")"
	;;
*)
	die "usage: $0 [brand|model|sn]"
	;;
esac
