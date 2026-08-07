#!/usr/bin/env bash
# Persist OP-TEE seal KEK as HUK-wrapped blob in Vendor Storage (ID 23),
# or restore REE FS cache from that blob. Does NOT touch cloud Ed25519 seed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

usage() {
	cat <<EOF
Usage: make migrate-seal-kek

On the selected board:
  - If VS ID 23 wrap is present → kek-import-wrap into REE TEE FS
  - Else → kek-export-wrap from REE (create KEK if needed) → write VS ID 23

Prereqs: vendor-signed secrets-seal TA/CA, tee-supplicant, /dev/vendor_storage,
read/write-seal-kek-wrapped helpers (rootfs with this change).

Selection: SN= / IP= (same as push-app).
EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: migrate-seal-kek on $TARGET_ADDR"
remote 'set -e
CA=/usr/libexec/board/secrets-seal-ca
SEAL=/usr/libexec/board/secrets-seal
READ=/usr/libexec/board/read-seal-kek-wrapped.sh
WRITE=/usr/libexec/board/write-seal-kek-wrapped.sh
[ -x "$CA" ] || { echo "ERROR: secrets-seal-ca missing"; exit 1; }
[ -x "$READ" ] && [ -x "$WRITE" ] || { echo "ERROR: seal-kek helpers missing — rebuild rootfs"; exit 1; }
if [ -x "$SEAL" ] && grep -q sync-kek "$SEAL" 2>/dev/null; then
  "$SEAL" sync-kek
else
  if "$READ" --present; then
    tmp=$(mktemp)
    "$READ" -o "$tmp"
    base64 <"$tmp" | tr -d "\n\r " | "$CA" kek-import-wrap
    rm -f "$tmp"
    echo "imported VS wrap → REE"
  else
    tmp=$(mktemp)
    "$CA" kek-export-wrap | base64 -d >"$tmp"
    FORCE=1 "$WRITE" -i "$tmp"
    rm -f "$tmp"
    echo "exported REE KEK → VS wrap"
  fi
fi
tmp=$(mktemp)
"$CA" kek-export-wrap | base64 -d >"$tmp"
sz=$(wc -c <"$tmp" | tr -d " ")
head -c 4 "$tmp" | od -An -tx1
rm -f "$tmp"
echo "verify export size=$sz"
echo "migrate-seal-kek: OK (cloud Ed25519 untouched)"
'

echo "OK: migrate-seal-kek finished"
