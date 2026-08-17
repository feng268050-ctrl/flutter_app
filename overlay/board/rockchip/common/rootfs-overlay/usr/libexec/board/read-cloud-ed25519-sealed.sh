#!/bin/sh
# Read sealed cloud Ed25519 private-key blob from Vendor Storage (ID 22) or
# provision/cloud-ed25519.sealed when /dev/vendor_storage is absent (emulator).
# Opaque Secrets ciphertext only — never plaintext.
#
# Usage:
#   read-cloud-ed25519-sealed.sh              # write raw bytes to stdout
#   read-cloud-ed25519-sealed.sh -o PATH      # write raw bytes to PATH
#   read-cloud-ed25519-sealed.sh --present    # exit 0 if blob present, 1 if absent
#
# Missing ID / no vendor_storage → provision file or empty (exit 0) for read;
# --present → exit 1 when absent everywhere.
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"
PROVISION_BLOB="${PROVISION_CLOUD_ED25519_SEALED:-/mnt/provision/cloud-ed25519.sealed}"

die() { echo "read-cloud-ed25519-sealed: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_CLOUD_ED25519_NAME:=VENDOR_CUSTOM_ID_16}"

vs_available() {
	[ -x "$VENDOR_STORAGE_BIN" ] && [ -e /dev/vendor_storage ]
}

provision_blob_present() {
	[ -f "$PROVISION_BLOB" ] && [ -s "$PROVISION_BLOB" ]
}

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

vs_blob_present() {
	local tmp
	tmp="$(mktemp)"
	if ! "$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$tmp" >/dev/null 2>&1; then
		rm -f "$tmp"
		return 1
	fi
	if [ ! -s "$tmp" ]; then
		rm -f "$tmp"
		return 1
	fi
	rm -f "$tmp"
	return 0
}

read_vs_blob_to() {
	local dest="$1"
	"$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$dest" >/dev/null 2>&1
}

read_provision_blob_to() {
	local dest="$1"
	if ! provision_blob_present; then
		return 1
	fi
	cp -f "$PROVISION_BLOB" "$dest"
}

blob_present() {
	if vs_available && vs_blob_present; then
		return 0
	fi
	provision_blob_present
}

read_blob_to() {
	local dest="$1"
	if vs_available; then
		if read_vs_blob_to "$dest" && [ -s "$dest" ]; then
			return 0
		fi
	fi
	read_provision_blob_to "$dest"
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
