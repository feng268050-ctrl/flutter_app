#!/usr/bin/env bash
# Re-seal software-KEK secrets → OP-TEE via running HMI (Wi‑Fi vault + cloud key).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

CMD_PATH="/run/hmi/migrate-secrets.cmd"
SCOPE="${SCOPE:-all}"

usage() {
	cat <<EOF
Usage: make migrate-secrets [SCOPE=all|wifi|cloud]

Writes $CMD_PATH so the running HMI unseals software-KEK (LWSS) blobs and
re-seals them with OP-TEE (LWS1):

  all   (default)  Wi‑Fi credentials.vault + Vendor Storage cloud Ed25519
  wifi             /var/lib/wpa_supplicant/credentials.vault only
  cloud            Vendor Storage ID 22 cloud Ed25519 sealed blob only

Prereqs:
  - HMI running (hmi.service) with MigrateSecretsCommandWatcher
  - secrets-seal probe OK (vendor-signed TA)
  - OEM secrets_backend already optee (so runtime uses OP-TEE after migrate)
  - Product SN present for cloud path (Vendor Storage identity)

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

case "$SCOPE" in
all | wifi | cloud) ;;
*)
	die "SCOPE must be all|wifi|cloud (got: $SCOPE)"
	;;
esac

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

if [[ "$SCOPE" == "all" ]]; then
	cmd_line="migrate"
else
	cmd_line="migrate $SCOPE"
fi

echo "INFO: writing migrate command: $CMD_PATH ($cmd_line)"
remote "mkdir -p /run/hmi && printf '%s\\n' '${cmd_line}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "OK: migrate-secrets command sent (no HMI restart)"
echo "INFO: filter device logs with: make logs GREP=MigrateSecrets"
