#!/usr/bin/env bash
# Detached Ed25519 signature over a file (SHA-512 digest, then Ed25519 sign).
# Env: OTA_SIGNING_KEY = path to Ed25519 private key (PEM).
# Usage: ota-sign.sh <input-file> [output.sig]
# Default output: <input-file>.sig
#
# Wire format: signature of SHA-512(file) bytes (64-byte digest), not raw file
# (Ed25519 via openssl pkeyutl cannot use dgst -sign).
set -euo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0 <input-file> [output.sig]

SHA-512 then Ed25519-sign the digest (openssl pkeyutl).
Requires OTA_SIGNING_KEY pointing at a PEM private key.

Examples:
  OTA_SIGNING_KEY=keys/ota/ed25519.pem $0 output/firmware/lws_hmi/ota-package.tar.gz
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0
[[ $# -ge 1 ]] || die "missing input file (see --help)"

IN="$1"
OUT="${2:-${IN}.sig}"
KEY="${OTA_SIGNING_KEY:-}"
DIGEST=""

[[ -n "$KEY" ]] || die "OTA_SIGNING_KEY is unset — set to Ed25519 PEM private key path"
[[ -r "$KEY" ]] || die "OTA_SIGNING_KEY not readable: $KEY"
[[ -f "$IN" ]] || die "input not found: $IN"
command -v openssl >/dev/null 2>&1 || die "openssl not found on PATH"

cleanup() {
	[[ -n "$DIGEST" && -f "$DIGEST" ]] && rm -f "$DIGEST"
}
trap cleanup EXIT

DIGEST="$(mktemp "${TMPDIR:-/tmp}/lws-ota-digest.XXXXXX")"
openssl dgst -sha512 -binary -out "$DIGEST" "$IN" \
	|| die "sha512 failed for $IN"
openssl pkeyutl -sign -inkey "$KEY" -in "$DIGEST" -out "$OUT" \
	|| die "openssl pkeyutl sign failed for $IN"
echo "ota-sign: wrote $OUT"
