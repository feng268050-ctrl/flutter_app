#!/usr/bin/env bash
# Shared USB-SSH helpers (host-side ECM link to 192.168.55.1).
# Compatible with macOS bash 3.2 (no nameref).
set -euo pipefail

USB_SSH_HOST_ADDR="${LWS_HMI_USB_HOST_ADDR:-192.168.55.2}"

sshpass_install_hint() {
	case "$(uname -s)" in
	Darwin) echo "  install: brew install esolitos/ipa/sshpass" ;;
	Linux)
		if command -v apt-get >/dev/null 2>&1; then
			echo "  install: sudo apt install sshpass"
		elif command -v dnf >/dev/null 2>&1; then
			echo "  install: sudo dnf install sshpass"
		elif command -v yum >/dev/null 2>&1; then
			echo "  install: sudo yum install sshpass"
		else
			echo "  install: sshpass (use your distro package manager)"
		fi
		;;
	*) echo "  install: sshpass (non-interactive SSH password for USB-SSH)" ;;
	esac
}

require_sshpass() {
	if command -v sshpass >/dev/null 2>&1; then
		return 0
	fi
	{
		echo "ERROR: sshpass is not installed (required for USB-SSH password login)."
		echo "  target: root@${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}  password: ${LWS_HMI_USB_SSH_PASS:-rockchip}"
		sshpass_install_hint
	} >&2
	exit 1
}

warn_sshpass_if_usb_ssh() {
	local n="${1:-0}"
	[[ "$n" -gt 0 ]] || return 0
	command -v sshpass >/dev/null 2>&1 && return 0
	{
		echo ""
		echo "NOTE: USB-SSH/SSH device(s) present — install sshpass for SERIAL lookup, push-app, and reboot:"
		sshpass_install_hint
	} >&2
}

# Print two lines: -o  then  Key=val  (append to ssh/scp argv with while-read).
usb_ssh_bind_pair() {
	local iface="$1"
	case "$(uname -s)" in
	Linux)
		printf '%s\n' "-o" "BindAddress=${USB_SSH_HOST_ADDR}"
		;;
	Darwin)
		printf '%s\n' "-o" "BindInterface=${iface}"
		;;
	*)
		printf '%s\n' "-o" "BindAddress=${USB_SSH_HOST_ADDR}"
		;;
	esac
}

configure_usb_ssh_host_addr() {
	local iface="$1"
	local host_addr="$USB_SSH_HOST_ADDR"
	local hint="Run 'make usb-ssh-setup' in an interactive terminal first."
	case "$(uname -s)" in
	Darwin)
		if ifconfig "$iface" 2>/dev/null | grep -qE "inet ${host_addr}[ /]"; then
			return 0
		fi
		if ifconfig "$iface" "$host_addr/24" up 2>/dev/null; then
			return 0
		fi
		if [[ -t 0 ]]; then
			sudo ifconfig "$iface" "$host_addr/24" up
		elif ! sudo -n ifconfig "$iface" "$host_addr/24" up 2>/dev/null; then
			echo "ERROR: $iface needs host address $host_addr/24. $hint" >&2
			return 1
		fi
		;;
	Linux)
		if ip -4 addr show dev "$iface" 2>/dev/null | grep -qE "inet ${host_addr}/"; then
			return 0
		fi
		if ip addr add "$host_addr/24" dev "$iface" 2>/dev/null && \
			ip link set "$iface" up 2>/dev/null; then
			return 0
		fi
		if [[ -t 0 ]]; then
			sudo ip addr replace "$host_addr/24" dev "$iface"
			sudo ip link set "$iface" up
		elif ! sudo -n ip addr replace "$host_addr/24" dev "$iface" 2>/dev/null || \
			! sudo -n ip link set "$iface" up 2>/dev/null; then
			echo "ERROR: $iface needs host address $host_addr/24. $hint" >&2
			return 1
		fi
		;;
	esac
}

ping_usb_ssh_target() {
	local iface="$1"
	local addr="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
	case "$(uname -s)" in
	Darwin) ping -c 1 -t 2 -b "$iface" "$addr" ;;
	Linux) ping -c 1 -W 2 -I "$iface" "$addr" ;;
	esac
}

# Background sysrq reboot; remote shell exits immediately (for make reboot / push-app).
USB_SSH_SYSRQ_REBOOT_CMD='sh -c "(sleep 1; sync; if [ -w /proc/sysrq-trigger ]; then echo 1 >/proc/sys/kernel/sysrq 2>/dev/null; echo b >/proc/sysrq-trigger; elif [ -x /usr/lib/lws-hmi/shutdown.sh ]; then /usr/lib/lws-hmi/shutdown.sh reboot; fi) >/dev/console 2>&1 & exit 0"'

# Unbound TCP reachability for registered remote SSH (MODE=SSH).
ping_remote_ssh_target() {
	local addr="$1"
	case "$(uname -s)" in
	Darwin) ping -c 1 -t 2 "$addr" ;;
	Linux) ping -c 1 -W 2 "$addr" ;;
	*) ping -c 1 "$addr" ;;
	esac
}

remote_ssh_run() {
	local target_addr="$1"
	shift
	local target_user="${LWS_HMI_USB_SSH_USER:-root}"
	local ssh_pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
	)

	require_sshpass
	sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" "$target_user@$target_addr" "$@"
}

remote_ssh_schedule_sysrq_reboot() {
	local target_addr="$1"
	echo "ssh ${LWS_HMI_USB_SSH_USER:-root}@${target_addr} sysrq reboot"
	remote_ssh_run "$target_addr" "$USB_SSH_SYSRQ_REBOOT_CMD" || true
}

usb_ssh_run() {
	local iface="$1"
	shift
	local target_addr="${LWS_HMI_USB_SSH_ADDR:-192.168.55.1}"
	local target_user="${LWS_HMI_USB_SSH_USER:-root}"
	local ssh_pass="${LWS_HMI_USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
	)

	require_sshpass
	configure_usb_ssh_host_addr "$iface"
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$iface")
	sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" "$target_user@$target_addr" "$@"
}

usb_ssh_schedule_sysrq_reboot() {
	local iface="$1"
	echo "ssh ${LWS_HMI_USB_SSH_USER:-root}@${LWS_HMI_USB_SSH_ADDR:-192.168.55.1} sysrq reboot"
	usb_ssh_run "$iface" "$USB_SSH_SYSRQ_REBOOT_CMD" || true
}

# Run remote command after brief delay in background; SSH returns without waiting for reset.
usb_ssh_schedule_remote() {
	local iface="$1" remote_cmd="$2"
	local remote_shell

	printf -v remote_shell 'sh -c "(sleep 1; %s) >/dev/console 2>&1 & exit 0"' "$remote_cmd"
	echo "ssh ${LWS_HMI_USB_SSH_USER:-root}@${LWS_HMI_USB_SSH_ADDR:-192.168.55.1} $remote_cmd"
	usb_ssh_run "$iface" "$remote_shell" || true
}
