#!/bin/sh
# Write product identity into Rockchip Vendor Storage or provision/identity.env.
# Env:
#   BRAND=  MODEL=  PRODUCT_SN=
#   FORCE=1 to overwrite a non-empty existing SN
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"
PROVISION_IDENTITY="${PROVISION_IDENTITY:-/mnt/provision/identity.env}"

die() { echo "write-product-identity: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_SN_NAME:=VENDOR_SN_ID}"
: "${VENDOR_BRAND_NAME:=VENDOR_CUSTOM_ID_14}"
: "${VENDOR_MODEL_NAME:=VENDOR_CUSTOM_ID_15}"
: "${VENDOR_SN_MAX_LEN:=30}"

BRAND="${BRAND:-}"
MODEL="${MODEL:-}"
PRODUCT_SN="${PRODUCT_SN:-}"
FORCE="${FORCE:-0}"

[ -n "$BRAND" ] || die "BRAND= is required"
[ -n "$MODEL" ] || die "MODEL= is required"
[ -n "$PRODUCT_SN" ] || die "PRODUCT_SN= is required"

trim() { printf '%s' "$1" | tr -d '\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
BRAND="$(trim "$BRAND")"
MODEL="$(trim "$MODEL")"
PRODUCT_SN="$(trim "$PRODUCT_SN")"

[ -n "$BRAND" ] || die "BRAND= empty after trim"
[ -n "$MODEL" ] || die "MODEL= empty after trim"
[ -n "$PRODUCT_SN" ] || die "PRODUCT_SN= empty after trim"

raw_sn="$PRODUCT_SN"
PRODUCT_SN="$(printf '%s' "$PRODUCT_SN" | tr -d '-')"
if [ "$PRODUCT_SN" != "$raw_sn" ]; then
	echo "write-product-identity: stripped '-' from PRODUCT_SN: '$raw_sn' → '$PRODUCT_SN'" >&2
fi
[ -n "$PRODUCT_SN" ] || die "PRODUCT_SN empty after stripping '-'"

case "$PRODUCT_SN" in
*[!A-Za-z0-9]*)
	die "PRODUCT_SN must be alphanumeric [A-Za-z0-9] (hyphens auto-stripped); got '$raw_sn' → '$PRODUCT_SN'"
	;;
esac

sn_len="$(printf '%s' "$PRODUCT_SN" | wc -c | tr -d ' ')"
[ "$sn_len" -le "$VENDOR_SN_MAX_LEN" ] \
	|| die "PRODUCT_SN length $sn_len exceeds max $VENDOR_SN_MAX_LEN"

write_provision_identity() {
	local existing_sn
	mkdir -p "$(dirname "$PROVISION_IDENTITY")"
	existing_sn=""
	if [ -f "$PROVISION_IDENTITY" ]; then
		existing_sn="$(grep -E '^sn=' "$PROVISION_IDENTITY" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' || true)"
	fi
	if [ -n "$existing_sn" ] && [ "$FORCE" != "1" ]; then
		die "provision SN already set to '$existing_sn' (pass FORCE=1 to overwrite)"
	fi
	{
		echo "brand=$BRAND"
		echo "model=$MODEL"
		echo "sn=$PRODUCT_SN"
	} >"$PROVISION_IDENTITY"
	chmod 0644 "$PROVISION_IDENTITY" 2>/dev/null || true
}

if [ -e /dev/vendor_storage ]; then
	[ -x "$VENDOR_STORAGE_BIN" ] \
		|| die "vendor_storage binary missing ($VENDOR_STORAGE_BIN) — rebuild rootfs with BR2_PACKAGE_RKTOOLKIT"

	read_sn() {
		local tmp out
		tmp="$(mktemp)"
		if ! "$VENDOR_STORAGE_BIN" -r "$VENDOR_SN_NAME" -t file -i "$tmp" >/dev/null 2>&1; then
			rm -f "$tmp"
			printf ''
			return 0
		fi
		out="$(tr -d '\000' <"$tmp" | tr -d '\r' | sed -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//')"
		rm -f "$tmp"
		printf '%s' "$out"
	}

	existing="$(read_sn)"
	if [ -n "$existing" ] && [ "$FORCE" != "1" ]; then
		die "Vendor Storage SN already set to '$existing' (pass FORCE=1 to overwrite)"
	fi

	write_id() {
		local name="$1" value="$2"
		"$VENDOR_STORAGE_BIN" -w "$name" -t string -i "$value" >/dev/null \
			|| die "failed writing $name"
	}

	write_id "$VENDOR_BRAND_NAME" "$BRAND"
	write_id "$VENDOR_MODEL_NAME" "$MODEL"
	write_id "$VENDOR_SN_NAME" "$PRODUCT_SN"
else
	[ -d /mnt/provision ] || die "/mnt/provision missing — mount provision partition first"
	write_provision_identity
fi

rb_brand="$(/usr/libexec/board/read-product-identity.sh brand)"
rb_model="$(/usr/libexec/board/read-product-identity.sh model)"
rb_sn="$(/usr/libexec/board/read-product-identity.sh sn)"
[ "$rb_brand" = "$BRAND" ] || die "readback brand mismatch: got '$rb_brand'"
[ "$rb_model" = "$MODEL" ] || die "readback model mismatch: got '$rb_model'"
[ "$rb_sn" = "$PRODUCT_SN" ] || die "readback sn mismatch: got '$rb_sn'"

echo "write-product-identity: OK brand='$BRAND' model='$MODEL' sn='$PRODUCT_SN'"
