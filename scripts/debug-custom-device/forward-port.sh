#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

HOST_PORT="${1:-}"
DEVICE_PORT="${2:-}"
[[ -n "$HOST_PORT" && -n "$DEVICE_PORT" ]] || {
	echo "usage: $0 <hostPort> <devicePort>" >&2
	exit 1
}

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

target_user="${TARGET_USER:-${LWS_HMI_USB_SSH_USER:-root}}"
target_addr="${TARGET_ADDR:-${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}}"
ssh_pass="${SSH_PASS:-${LWS_HMI_USB_SSH_PASS:-rockchip}}"
control_path="$(usb_ssh_session_control_path "$(usb_ssh_session_control_key "$IFACE")")"
declare -a ssh_opts=(
	-o ConnectTimeout=5
	-o StrictHostKeyChecking=accept-new
	-o UserKnownHostsFile=/dev/null
	-o LogLevel=ERROR
	-o PreferredAuthentications=password
	-o PubkeyAuthentication=no
	-o KbdInteractiveAuthentication=no
	-o NumberOfPasswordPrompts=1
	-o ControlMaster=auto
	-o ControlPersist=30
	-o "ControlPath=$control_path"
	-o ExitOnForwardFailure=yes
	-o ServerAliveInterval=15
	-L "127.0.0.1:${HOST_PORT}:127.0.0.1:${DEVICE_PORT}"
)
if ! usb_ssh_session_is_remote; then
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$IFACE")
fi

require_sshpass
sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" -N "$target_user@$target_addr" &
ssh_pid=$!
trap 'kill "$ssh_pid" 2>/dev/null || true' EXIT INT TERM

for _ in {1..20}; do
	if ! kill -0 "$ssh_pid" 2>/dev/null; then
		wait "$ssh_pid"
	fi
	if nc -z 127.0.0.1 "$HOST_PORT" >/dev/null 2>&1; then
		echo "Port forwarding success"
		wait "$ssh_pid"
		exit $?
	fi
	sleep 0.1
done

echo "ERROR: SSH started but local port $HOST_PORT was not forwarded" >&2
exit 1
