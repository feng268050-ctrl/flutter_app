#!/bin/sh
# Read sealed cloud Ed25519 private-key blob from Vendor Storage (ID 22).
# Opaque Secrets ciphertext only — never plaintext.
#
# Usage:
#   read-cloud-ed25519-sealed.sh              # write raw bytes to stdout
#   read-cloud-ed25519-sealed.sh -o PATH      # write raw bytes to PATH
#   read-cloud-ed25519-sealed.sh --present    # exit 0 if blob present, 1 if absent
#
# Missing ID / no vendor_storage → empty (exit 0) for read; --present → exit 1.
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"

die() { echo "read-cloud-ed25519-sealed: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_CLOUD_ED25519_NAME:=VENDOR_CUSTOM_ID_16}"

MODE=stdout
OUT_PATH=
case "${1:-}" in
'')
	;;
-o | --output)
	[ -n "${2:-}" ] || die "usage: $0 [-o PATH | --present]"
	MODE=file
	OUT_PATH="$2"
	;;
--present)
	MODE=present
	;;
-h | --help)
	echo "usage: $0 [-o PATH | --present]"
	exit 0
	;;
*)
	die "usage: $0 [-o PATH | --present]"
	;;
esac

blob_present() {
	local tmp
	[ -x "$VENDOR_STORAGE_BIN" ] || return 1
	[ -e /dev/vendor_storage ] || return 1
	tmp="$(mktemp)"
	if ! "$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$tmp" >/dev/null 2>&1; then
		rm -f "$tmp"
		return 1
	fi
	# Empty / zero-length → treat as absent.
	if [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		return 1
	fi
	rm -f "$tmp"
	return 0
}

read_blob_to() {
	local dest="$1"
	[ -x "$VENDOR_STORAGE_BIN" ] || return 1
	[ -e /dev/vendor_storage ] || return 1
	"$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$dest" >/dev/null 2>&1
}

case "$MODE" in
present)
	if blob_present; then
		exit 0
	fi
	exit 1
	;;
file)
	tmp="$(mktemp)"
	if ! read_blob_to "$tmp" || [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		# Missing → empty file at dest (caller checks size).
		: >"$OUT_PATH"
		exit 0
	fi
	mv -f "$tmp" "$OUT_PATH"
	;;
stdout)
	tmp="$(mktemp)"
	if ! read_blob_to "$tmp" || [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		exit 0
	fi
	cat "$tmp"
	rm -f "$tmp"
	;;
esac
