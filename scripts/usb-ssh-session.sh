#!/usr/bin/env bash
# Shared USB-SSH session helpers for push-app, debug-app, and custom-device adapters.
set -euo pipefail

usb_ssh_session_root() {
	local self="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
	cd "$(dirname "$self")/.." && pwd
}

usb_ssh_session_die() {
	echo "ERROR: $*" >&2
	exit 1
}

usb_ssh_session_load_env() {
	local root="$1"
	# shellcheck source=scripts/usb-ssh-common.sh
	source "$root/scripts/usb-ssh-common.sh"
	local env_file="$root/.env"
	if [[ -f "$env_file" ]]; then
		set -a
		# shellcheck source=/dev/null
		source "$env_file"
		set +a
	fi
	SERIAL="${SERIAL:-${LWS_HMI_SERIAL:-}}"
	TARGET_ADDR="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
	TARGET_USER="${LWS_HMI_USB_SSH_USER:-root}"
	SSH_PASS="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	WAIT_SEC="${PUSH_APP_WAIT_SEC:-30}"
}

usb_ssh_session_select() {
	local root="$1"
	local -a sel=()
	while IFS= read -r line; do
		sel+=("$line")
	done < <(SERIAL="$SERIAL" bash "$root/scripts/usb-ssh-devices.sh" --select)
	[[ ${#sel[@]} -eq 3 ]] || usb_ssh_session_die "could not select USB-SSH device"
	IFACE="${sel[1]}"
	[[ "$IFACE" != "-" && -n "$IFACE" ]] || usb_ssh_session_die "no host interface for USB-SSH device (wait for ECM link)"
}

usb_ssh_session_wait_for_target() {
	local iface="$1" addr="$2" wait_sec="$3"
	local i
	for ((i = 1; i <= wait_sec; i++)); do
		if ping_usb_ssh_target "$iface" >/dev/null 2>&1; then
			echo "Target reachable on $addr via $iface (${i}s)."
			return 0
		fi
		if (( i == 1 || i % 5 == 0 )); then
			echo "Waiting for $addr on $iface... (${i}s)"
		fi
		sleep 1
	done
	usb_ssh_session_die "Timed out waiting for $addr on $iface (plug USB, wait for ECM)"
}

usb_ssh_session_control_path() {
	local iface="$1"
	local dir="/tmp/lws-hmi-ssh-${UID:-$(id -u)}"
	mkdir -p "$dir"
	chmod 0700 "$dir"
	printf '%s/%s-%%C\n' "$dir" "$iface"
}

usb_ssh_session_run_ssh() {
	local root="$1" iface="$2"
	shift 2
	local target_user="${LWS_HMI_USB_SSH_USER:-root}"
	local target_addr="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
	local ssh_pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local control_path
	control_path="$(usb_ssh_session_control_path "$iface")"
	local -a ssh_opts=(
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
	)
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$iface")
	require_sshpass
	sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" "$target_user@$target_addr" "$@"
}

usb_ssh_session_run_scp() {
	local root="$1" iface="$2"
	shift 2
	local target_user="${LWS_HMI_USB_SSH_USER:-root}"
	local target_addr="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
	local ssh_pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local attempt status
	local control_path
	control_path="$(usb_ssh_session_control_path "$iface")"
	local -a ssh_opts=(
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
	)
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$iface")
	require_sshpass
	for attempt in 1 2 3; do
		if sshpass -p "$ssh_pass" scp "${ssh_opts[@]}" "$@"; then
			return 0
		else
			status=$?
		fi
		if [[ "$status" -ne 255 || "$attempt" -eq 3 ]]; then
			return "$status"
		fi
		echo "USB-SSH SCP connection failed; retrying ($attempt/3)..." >&2
		sleep "$attempt"
	done
}

usb_ssh_session_open_control() {
	local root="$1" iface="$2"
	local attempt
	for attempt in 1 2 3; do
		if usb_ssh_session_run_ssh "$root" "$iface" true; then
			return 0
		fi
		if [[ "$attempt" -lt 3 ]]; then
			echo "USB-SSH authentication failed; retrying control connection ($attempt/3)..." >&2
			sleep "$attempt"
		fi
	done
	return 1
}

usb_ssh_session_prepare() {
	local root="$1"
	usb_ssh_session_load_env "$root"
	usb_ssh_session_select "$root"
	configure_usb_ssh_host_addr "$IFACE"
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"
	usb_ssh_session_open_control "$root" "$IFACE"
}
