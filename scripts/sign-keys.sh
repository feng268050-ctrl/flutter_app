#!/usr/bin/env bash
# Generate or refresh the **release** Ed25519 OTA keypair and install the pubkey
# into rootfs overlay at /etc/ota/ed25519.pub.
# Private key stays under keys/ota/ (gitignored). Never copy private key to overlay.
# There is no separate lab/dev keypair — cloud verify uses this release pubkey only.
# Usage: make sign-keys   OR   bash scripts/sign-keys.sh
# Env: FORCE=1 to overwrite existing private key (breaks previously signed packages).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_DIR="${OTA_KEY_DIR:-$ROOT/keys/ota}"
PRIV="$KEY_DIR/ed25519.pem"
PUB_HOST="$KEY_DIR/ed25519.pub"
PUB_OVERLAY="$ROOT/overlay/board/rockchip/common/rootfs-overlay/etc/ota/ed25519.pub"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

command -v openssl >/dev/null 2>&1 || die "openssl not found on PATH"

mkdir -p "$KEY_DIR" "$(dirname "$PUB_OVERLAY")"

if [[ -f "$PRIV" && "${FORCE:-0}" != "1" ]]; then
	echo "sign-keys: keeping existing $PRIV (FORCE=1 to regenerate — invalidates old .sig)"
else
	openssl genpkey -algorithm Ed25519 -out "$PRIV"
	chmod 600 "$PRIV"
	echo "sign-keys: wrote $PRIV"
fi

openssl pkey -in "$PRIV" -pubout -out "$PUB_HOST"
cp -f "$PUB_HOST" "$PUB_OVERLAY"
chmod 644 "$PUB_OVERLAY" "$PUB_HOST"

echo "sign-keys: host pubkey     $PUB_HOST"
echo "sign-keys: overlay pubkey  $PUB_OVERLAY"
echo "sign-keys: private key MUST NOT be committed or shipped in rootfs"
echo "sign-keys: sign publish packages with:"
echo "  OTA_SIGNING_KEY=$PRIV REQUIRE_OTA_SIG=1 make pack-ota"
