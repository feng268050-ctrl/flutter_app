#!/bin/sh
# Write sealed cloud Ed25519 private-key blob into Vendor Storage (ID 22).
# Opaque Secrets ciphertext only — never plaintext.
#
# Env / args:
#   INPUT=PATH   or  -i PATH   path to sealed blob file
#   FORCE=1                    overwrite an existing non-empty blob (after-sales only)
#
# Exits non-zero if /dev/vendor_storage is unavailable (e.g. QEMU emulator).
# Refuses overwrite when a blob is already present unless FORCE=1.
set -eu

IDS_FILE="${VENDOR_STORAGE_IDS:-/usr/libexec/board/vendor-storage-ids.txt}"
VENDOR_STORAGE_BIN="${VENDOR_STORAGE_BIN:-/usr/bin/vendor_storage}"

die() { echo "write-cloud-ed25519-sealed: ERROR: $*" >&2; exit 1; }

# shellcheck disable=SC1090
[ -r "$IDS_FILE" ] || die "missing ID map: $IDS_FILE"
# shellcheck source=/dev/null
. "$IDS_FILE"

: "${VENDOR_CLOUD_ED25519_NAME:=VENDOR_CUSTOM_ID_16}"
: "${VENDOR_CLOUD_ED25519_MAX_LEN:=1024}"

INPUT="${INPUT:-}"
FORCE="${FORCE:-0}"

while [ $# -gt 0 ]; do
	case "$1" in
	-i | --input)
		[ -n "${2:-}" ] || die "usage: $0 -i PATH"
		INPUT="$2"
		shift 2
		;;
	--force)
		FORCE=1
		shift
		;;
	-h | --help)
		echo "usage: $0 -i PATH   (or INPUT=PATH); FORCE=1 to overwrite"
		exit 0
		;;
	*)
		die "usage: $0 -i PATH   (or INPUT=PATH); FORCE=1 to overwrite"
		;;
	esac
done

[ -n "$INPUT" ] || die "INPUT= / -i PATH is required"
[ -f "$INPUT" ] || die "input file missing: $INPUT"
[ -s "$INPUT" ] || die "input file empty: $INPUT"

size="$(wc -c <"$INPUT" | tr -d ' ')"
[ "$size" -le "$VENDOR_CLOUD_ED25519_MAX_LEN" ] \
	|| die "sealed blob length $size exceeds max $VENDOR_CLOUD_ED25519_MAX_LEN"

[ -x "$VENDOR_STORAGE_BIN" ] \
	|| die "vendor_storage binary missing ($VENDOR_STORAGE_BIN) — rebuild rootfs with BR2_PACKAGE_RKTOOLKIT"
[ -e /dev/vendor_storage ] \
	|| die "/dev/vendor_storage missing — flash GPT with vendor0–vendor3, or use real hardware (not emulator)"

# Presence check (non-empty existing blob).
existing_tmp="$(mktemp)"
if "$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$existing_tmp" >/dev/null 2>&1 \
	&& [ -s "$existing_tmp" ]; then
	rm -f "$existing_tmp"
	if [ "$FORCE" != "1" ]; then
		die "cloud Ed25519 sealed blob already present (pass FORCE=1 to overwrite — after-sales only)"
	fi
else
	rm -f "$existing_tmp"
fi

"$VENDOR_STORAGE_BIN" -w "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$INPUT" >/dev/null \
	|| die "failed writing $VENDOR_CLOUD_ED25519_NAME"

# Readback verify (byte size match).
rb="$(mktemp)"
"$VENDOR_STORAGE_BIN" -r "$VENDOR_CLOUD_ED25519_NAME" -t file -i "$rb" >/dev/null 2>&1 \
	|| die "readback failed after write"
rb_size="$(wc -c <"$rb" | tr -d ' ')"
rm -f "$rb"
[ "$rb_size" = "$size" ] || die "readback size mismatch: wrote $size got $rb_size"

echo "write-cloud-ed25519-sealed: OK id=$VENDOR_CLOUD_ED25519_NAME bytes=$size"
