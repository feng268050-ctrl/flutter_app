#!/usr/bin/env bash
# Team SSH host key → keys/ssh/id_ed25519 (gitignored) + rootfs authorized_keys overlay.
# Private key is distributed inside the company only; pubkey ships in every rootfs.
# Recovery when key is lost: TTL serial console login, rewrite /root/.ssh/authorized_keys.
# Usage: make ssh-keys   OR   bash scripts/ssh-keys.sh
# Env: FORCE=1 to regenerate id_ed25519 (invalidates existing host logins until boards reflashed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEY_DIR="${LWS_SSH_KEY_DIR:-$ROOT/keys/ssh}"
PRIV="$KEY_DIR/id_ed25519"
PUB="$KEY_DIR/id_ed25519.pub"
AUTH_OVERLAY="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/root/.ssh/authorized_keys"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen not found on PATH"

mkdir -p "$KEY_DIR" "$(dirname "$AUTH_OVERLAY")"

if [[ -f "$PRIV" && "${FORCE:-0}" != "1" ]]; then
	echo "ssh-keys: keeping existing $PRIV (FORCE=1 to regenerate)"
else
	ssh-keygen -t ed25519 -f "$PRIV" -N "" -C "it@lasercyber.com"
	chmod 600 "$PRIV"
	echo "ssh-keys: wrote $PRIV"
fi

[[ -f "$PUB" ]] || die "missing $PUB after ssh-keygen"
cp -f "$PUB" "$AUTH_OVERLAY"
chmod 644 "$AUTH_OVERLAY" "$PUB"

echo "ssh-keys: host pubkey      $PUB"
echo "ssh-keys: overlay auth     $AUTH_OVERLAY"
echo "ssh-keys: private key MUST NOT be committed (see .gitignore)"
echo "ssh-keys: distribute $PRIV to developers internally"
echo "ssh-keys: host Make targets use: LWS_SSH_IDENTITY=$PRIV"
