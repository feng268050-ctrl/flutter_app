#!/usr/bin/env bash
# Shared USB-SSH / remote SSH session helpers for push-app, debug-app, and custom-device adapters.
# After usb_ssh_session_select: TRANSPORT (usb-ssh|ssh), IFACE, TARGET_ADDR, LOCATION_ID.
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
	SERIAL="${SERIAL:-}"
	SN="${SN:-$SERIAL}"
	CHIP_ID="${CHIP_ID:-}"
	IP="${IP:-}"
	TARGET_USER="${USB_SSH_USER:-root}"
	SSH_IDENTITY_ROOT="$root"
	WAIT_SEC=30
	# Default USB gadget address; overridden by select for MODE=SSH.
	TARGET_ADDR="${USB_SSH_ADDR:-192.168.55.1}"
	TRANSPORT=""
	IFACE=""
	LOCATION_ID=""
	# Reject deprecated CHIP_ID= before select (device_select_sn also checks).
	reject_chip_id_env
}

usb_ssh_session_is_remote() {
	[[ "${TRANSPORT:-}" == "ssh" ]]
}

usb_ssh_session_select() {
	local root="$1"
	usb_ssh_session_try_select "$root" || usb_ssh_session_die "could not select USB-SSH/SSH device"
}

# Like select, but returns 1 instead of exiting (for prepare-debug-host fallback).
usb_ssh_session_try_select() {
	local root="$1"
	local out line errfile
	local -a sel=()
	errfile="$(mktemp "${TMPDIR:-/tmp}/lws-device-select.XXXXXX")"
	if ! out=$(
		SN="$SN" CHIP_ID="$CHIP_ID" SERIAL="$SERIAL" IP="$IP" IFACE="${IFACE:-}" \
			bash "$root/scripts/device-target.sh" --select 2>"$errfile"
	); then
		[[ -s "$errfile" ]] && cat "$errfile" >&2
		rm -f "$errfile"
		return 1
	fi
	rm -f "$errfile"
	while IFS= read -r line; do
		[[ -n "$line" ]] && sel+=("$line")
	done <<<"$out"
	[[ ${#sel[@]} -eq 4 ]] || return 1
	TRANSPORT="${sel[0]}"
	LOCATION_ID="${sel[1]}"
	IFACE="${sel[2]}"
	TARGET_ADDR="${sel[3]}"
	case "$TRANSPORT" in
	usb-ssh)
		[[ "$IFACE" != "-" && -n "$IFACE" ]] || return 1
		TARGET_ADDR="${TARGET_ADDR:-${USB_SSH_ADDR:-192.168.55.1}}"
		;;
	ssh)
		IFACE="-"
		[[ -n "$TARGET_ADDR" && "$TARGET_ADDR" != "-" ]] || return 1
		;;
	*)
		return 1
		;;
	esac
	return 0
}

usb_ssh_session_configure_link() {
	usb_ssh_session_is_remote && return 0
	configure_usb_ssh_host_addr "$IFACE"
}

usb_ssh_session_wait_for_target() {
	local iface="$1" addr="$2" wait_sec="$3"
	local i
	for ((i = 1; i <= wait_sec; i++)); do
		if usb_ssh_session_is_remote; then
			if ping_remote_ssh_target "$addr" >/dev/null 2>&1; then
				echo "Target reachable on $addr (${i}s)."
				return 0
			fi
		else
			if ping_usb_ssh_target "$iface" >/dev/null 2>&1; then
				echo "Target reachable on $addr via $iface (${i}s)."
				return 0
			fi
		fi
		if (( i == 1 || i % 5 == 0 )); then
			if usb_ssh_session_is_remote; then
				echo "Waiting for $addr... (${i}s)"
			else
				echo "Waiting for $addr on $iface... (${i}s)"
			fi
		fi
		sleep 1
	done
	if usb_ssh_session_is_remote; then
		usb_ssh_session_die "Timed out waiting for $addr (check IP / sshd / make connect)"
	fi
	usb_ssh_session_die "Timed out waiting for $addr on $iface (plug USB, wait for ECM)"
}

usb_ssh_session_control_path() {
	local key="$1"
	local dir="/tmp/hmi-ssh-${UID:-$(id -u)}"
	mkdir -p "$dir"
	chmod 0700 "$dir"
	key="${key//[^A-Za-z0-9._-]/_}"
	[[ -n "$key" ]] || key="default"
	printf '%s/%s-%%C\n' "$dir" "$key"
}

usb_ssh_session_control_key() {
	local iface="${1:-${IFACE:--}}"
	if usb_ssh_session_is_remote || [[ "$iface" == "-" || -z "$iface" ]]; then
		printf '%s\n' "ssh-${TARGET_ADDR}"
	else
		printf '%s\n' "$iface"
	fi
}

usb_ssh_session_run_ssh() {
	local root="$1" iface="$2"
	shift 2
	local target_user="${TARGET_USER:-${USB_SSH_USER:-root}}"
	local target_addr="${TARGET_ADDR:-${USB_SSH_ADDR:-192.168.55.1}}"
	local control_path host port
	control_path="$(usb_ssh_session_control_path "$(usb_ssh_session_control_key "$iface")")"
	local -a ssh_opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
		-o ControlMaster=auto
		-o ControlPersist=30
		-o "ControlPath=$control_path"
	)
	[[ "${LWS_SSH_TTY:-0}" == "1" ]] && ssh_opts+=(-t)
	if [[ "$iface" != "-" && -n "$iface" ]] && ! usb_ssh_session_is_remote; then
		local opt
		while IFS= read -r opt; do
			[[ -n "$opt" ]] && ssh_opts+=("$opt")
		done < <(usb_ssh_bind_pair "$iface")
	fi
	require_ssh_identity "$root"
	parse_ssh_endpoint "$target_addr" || usb_ssh_session_die "invalid SSH endpoint: $target_addr"
	host="$_SSH_HOST"
	port="$_SSH_PORT"
	ssh_opts+=(-p "$port")
	lws_ssh_auth_opts "$root" ssh_opts
	ssh "${ssh_opts[@]}" "$target_user@$host" "$@"
}

usb_ssh_session_run_scp() {
	local root="$1" iface="$2"
	shift 2
	local target_user="${TARGET_USER:-${USB_SSH_USER:-root}}"
	local target_addr="${TARGET_ADDR:-${USB_SSH_ADDR:-192.168.55.1}}"
	local attempt status host port
	local control_path
	control_path="$(usb_ssh_session_control_path "$(usb_ssh_session_control_key "$iface")")"
	local -a ssh_opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
		-o ControlMaster=auto
		-o ControlPersist=30
		-o "ControlPath=$control_path"
	)
	if [[ "$iface" != "-" && -n "$iface" ]] && ! usb_ssh_session_is_remote; then
		local opt
		while IFS= read -r opt; do
			[[ -n "$opt" ]] && ssh_opts+=("$opt")
		done < <(usb_ssh_bind_pair "$iface")
	fi
	require_ssh_identity "$root"
	parse_ssh_endpoint "$target_addr" || usb_ssh_session_die "invalid SSH endpoint: $target_addr"
	host="$_SSH_HOST"
	port="$_SSH_PORT"
	# Rewrite remote user@addr: paths to user@host: and pass -P for scp.
	local -a scp_args=()
	local a
	for a in "$@"; do
		if [[ "$a" == "${target_user}@${target_addr}:"* ]]; then
			scp_args+=("${target_user}@${host}:${a#${target_user}@${target_addr}:}")
		elif [[ "$a" == *"@${target_addr}:"* ]]; then
			scp_args+=("${a/@${target_addr}:/@${host}:}")
		else
			scp_args+=("$a")
		fi
	done
	ssh_opts+=(-P "$port")
	lws_ssh_auth_opts "$root" ssh_opts
	for attempt in 1 2 3; do
		if scp "${ssh_opts[@]}" "${scp_args[@]}"; then
			return 0
		else
			status=$?
		fi
		if [[ "$status" -ne 255 || "$attempt" -eq 3 ]]; then
			return "$status"
		fi
		echo "SSH SCP connection failed; retrying ($attempt/3)..." >&2
		sleep "$attempt"
	done
}

usb_ssh_session_open_control() {
	local root="$1" iface="${2:-$IFACE}"
	local attempt
	for attempt in 1 2 3; do
		if usb_ssh_session_run_ssh "$root" "$iface" true; then
			return 0
		fi
		if [[ "$attempt" -lt 3 ]]; then
			echo "SSH authentication failed; retrying control connection ($attempt/3)..." >&2
			sleep "$attempt"
		fi
	done
	return 1
}

usb_ssh_session_prepare() {
	local root="$1"
	usb_ssh_session_load_env "$root"
	usb_ssh_session_select "$root"
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"
	usb_ssh_session_open_control "$root" "$IFACE"
}
