#!/usr/bin/env bash
# Shared USB-SSH helpers (host-side ECM link to 192.168.55.1).
# Compatible with macOS bash 3.2 (no nameref).
set -euo pipefail

USB_SSH_HOST_ADDR="${LWS_HMI_USB_HOST_ADDR:-192.168.55.2}"
_USB_SSH_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# darwin | linux | windows | unknown
usb_ssh_host_os() {
	case "$(uname -s)" in
	Darwin) echo darwin ;;
	Linux) echo linux ;;
	MINGW* | MSYS* | CYGWIN*) echo windows ;;
	*) echo unknown ;;
	esac
}

usb_ssh_windows_ps1() {
	local ps1="$_USB_SSH_COMMON_DIR/usb-ssh-windows.ps1"
	local winpath="$ps1"
	command -v powershell.exe >/dev/null 2>&1 || {
		echo "ERROR: powershell.exe not found (required for Windows USB-SSH)" >&2
		return 1
	}
	[[ -f "$ps1" ]] || {
		echo "ERROR: missing $ps1" >&2
		return 1
	}
	if command -v cygpath >/dev/null 2>&1; then
		winpath="$(cygpath -w "$ps1")"
	fi
	powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$winpath" "$@"
}

sshpass_install_hint() {
	case "$(usb_ssh_host_os)" in
	darwin) echo "  install: brew install esolitos/ipa/sshpass" ;;
	linux)
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
	windows)
		echo "  install (MSYS2): pacman -S sshpass"
		echo "  or: scoop install sshpass / choco install sshpass"
		;;
	*) echo "  install: sshpass (non-interactive SSH password for USB-SSH)" ;;
	esac
}

# Android AVD serials look like emulator-5554 (not physical adb / RockUSB boards).
is_android_emulator_serial() {
	case "${1:-}" in
	emulator-*) return 0 ;;
	*) return 1 ;;
	esac
}

# SSH endpoint: host or host:port (IPv4 / simple hostname). Default port 22.
# Sets _SSH_HOST and _SSH_PORT (callers may read after success).
parse_ssh_endpoint() {
	local ep="${1:-}"
	_SSH_HOST=""
	_SSH_PORT=22
	[[ -n "$ep" ]] || return 1
	# Wrap the full IPv4 in an outer group — repeated (...){3} only keeps the last iter.
	if [[ "$ep" =~ ^(([0-9]{1,3}\.){3}[0-9]{1,3}):([0-9]{1,5})$ ]]; then
		_SSH_HOST="${BASH_REMATCH[1]}"
		_SSH_PORT="${BASH_REMATCH[3]}"
		return 0
	fi
	if [[ "$ep" =~ ^([A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?):([0-9]{1,5})$ ]]; then
		_SSH_HOST="${BASH_REMATCH[1]}"
		_SSH_PORT="${BASH_REMATCH[3]}"
		return 0
	fi
	if [[ "$ep" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
		_SSH_HOST="$ep"
		return 0
	fi
	if [[ "$ep" =~ ^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$ ]]; then
		_SSH_HOST="$ep"
		return 0
	fi
	return 1
}

normalize_ssh_endpoint() {
	parse_ssh_endpoint "$1" || return 1
	if [[ "$_SSH_PORT" == "22" ]]; then
		printf '%s\n' "$_SSH_HOST"
	else
		printf '%s\n' "${_SSH_HOST}:${_SSH_PORT}"
	fi
}

# True for QEMU guest hostfwd endpoints (make devices MODE=EMU).
is_emulator_ssh_endpoint() {
	local ep="${1:-}"
	parse_ssh_endpoint "$ep" || return 1
	case "$_SSH_HOST" in
	127.0.0.1 | localhost)
		[[ "$_SSH_PORT" != "22" ]] && return 0
		;;
	esac
	return 1
}

# TCP check for SSH (ping is wrong for host:port / loopback hostfwd).
ssh_endpoint_reachable() {
	local ep="${1:-}" host port
	parse_ssh_endpoint "$ep" || return 1
	host="$_SSH_HOST"
	port="$_SSH_PORT"
	if command -v nc >/dev/null 2>&1; then
		nc -z -G 2 "$host" "$port" >/dev/null 2>&1 || nc -z -w 2 "$host" "$port" >/dev/null 2>&1
		return $?
	fi
	# Bash /dev/tcp (macOS bash 3.2 OK)
	(echo >/dev/tcp/"$host"/"$port") >/dev/null 2>&1
}

# Device selection: SN (or deprecated SERIAL) matches make devices SN or ChipID columns.
# CHIP_ID matches ChipID only (when SN= would be ambiguous across boards).
device_select_sn() {
	printf '%s' "${SN:-${SERIAL:-}}"
}

device_select_chip_id() {
	printf '%s' "${CHIP_ID:-}"
}

# Remote shell snippet: print SN<TAB>ChipID.
# SN: Vendor Storage via read-serial (same as ProductInfo); empty → chip ID.
# ChipID ALWAYS uses an inline DT/cpuinfo path — never `read-serial --chip-id` alone
# as the only source on half-upgraded boards; prefer chip helper when present.
remote_device_identity_sh() {
	cat <<'EOF'
read_chip() {
	if [ -x /usr/bin/read-serial ]; then
		c=$(/usr/bin/read-serial --chip-id 2>/dev/null | tr -d '\r' | head -n1)
		c="${c#"${c%%[![:space:]]*}"}"
		c="${c%"${c##*[![:space:]]}"}"
		if [ -n "$c" ] && [ "$c" != "-" ]; then
			printf '%s\n' "$c"
			return 0
		fi
	fi
	for p in /proc/device-tree/serial-number /sys/firmware/devicetree/base/serial-number; do
		[ -r "$p" ] || continue
		tr -d '\0' <"$p"
		return 0
	done
	if [ -r /proc/cpuinfo ]; then
		s=$(awk -F: '/^[[:space:]]*Serial[[:space:]]*:/ {
			gsub(/^[ \t]+/, "", $2)
			print $2
			exit
		}' /proc/cpuinfo)
		if [ -n "$s" ]; then
			printf '%s\n' "$s"
			return 0
		fi
	fi
	if [ -r /etc/machine-id ]; then
		printf 'lws-%s\n' "$(cat /etc/machine-id)"
		return 0
	fi
	printf '%s\n' '-'
}
chip="$(read_chip | tr -d '\r' | head -n1)"
chip="${chip#"${chip%%[![:space:]]*}"}"
chip="${chip%"${chip##*[![:space:]]}"}"
[ -n "$chip" ] || chip="-"
sn=""
if [ -x /usr/bin/read-serial ]; then
	sn=$(/usr/bin/read-serial 2>/dev/null | tr -d '\r' | head -n1)
fi
sn="${sn#"${sn%%[![:space:]]*}"}"
sn="${sn%"${sn##*[![:space:]]}"}"
if [ -z "$sn" ] || [ "$sn" = "-" ]; then
	sn="$chip"
fi
printf '%s\t%s\n' "$sn" "$chip"
EOF
}

# Prints SN<TAB>ChipID via remote SSH argv prefix (sshpass/ssh … user@host).
# Pipe the script on stdin — do NOT use `ssh … sh -c "$(script)"`: remote shells
# expand $vars / break awk inside the -c string, which collapses SN to ChipID.
remote_device_identity_via_ssh() {
	local out sn chip
	out="$(remote_device_identity_sh | "$@" sh 2>/dev/null | tr -d '\r' | head -n1 || true)"
	out="${out#"${out%%[![:space:]]*}"}"
	out="${out%"${out##*[![:space:]]}"}"
	[[ -n "$out" ]] || return 1
	IFS=$'\t' read -r sn chip <<<"$out"
	[[ -n "$sn" ]] || sn="-"
	[[ -n "$chip" ]] || chip="-"
	printf '%s\t%s\n' "$sn" "$chip"
}

# Back-compat: SN only (first field of identity probe).
remote_device_serial_via_ssh() {
	local pair sn chip
	pair="$(remote_device_identity_via_ssh "$@" || true)"
	[[ -n "$pair" ]] || return 1
	IFS=$'\t' read -r sn chip <<<"$pair"
	[[ -n "$sn" && "$sn" != "-" ]] || return 1
	printf '%s\n' "$sn"
}

# Deprecated name kept for callers; prefer remote_device_identity_sh.
remote_device_serial_sh() {
	remote_device_identity_sh
}

require_sshpass() {
	if command -v sshpass >/dev/null 2>&1; then
		return 0
	fi
	{
		echo "ERROR: sshpass is not installed (required for USB-SSH password login)."
		echo "  target: root@${USB_SSH_ADDR:-192.168.55.1}  password: ${USB_SSH_PASS:-rockchip}"
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
		echo "NOTE: USB-SSH/SSH device(s) present — install sshpass for SN/ChipID lookup, push-app, and reboot:"
		sshpass_install_hint
	} >&2
}

# Print two lines: -o  then  Key=val  (append to ssh/scp argv with while-read).
usb_ssh_bind_pair() {
	local iface="$1"
	case "$(usb_ssh_host_os)" in
	linux | windows)
		# Bind by host USB link address (iface name may contain spaces on Windows).
		printf '%s\n' "-o" "BindAddress=${USB_SSH_HOST_ADDR}"
		;;
	darwin)
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
	local hint="Run 'make setup-usb-ssh' in an interactive terminal first (may need Administrator on Windows)."
	case "$(usb_ssh_host_os)" in
	darwin)
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
	linux)
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
	windows)
		if usb_ssh_windows_ps1 -Action has-ip -Alias "$iface" -HostAddress "$host_addr" >/dev/null 2>&1; then
			return 0
		fi
		if usb_ssh_windows_ps1 -Action set-ip -Alias "$iface" -HostAddress "$host_addr" -PrefixLength 24 >/dev/null 2>&1; then
			return 0
		fi
		echo "ERROR: interface '$iface' needs host address $host_addr/24. $hint" >&2
		echo "  Board gadget should appear as Remote NDIS / Ethernet after Rockchip USB drivers are installed." >&2
		return 1
		;;
	*)
		echo "ERROR: unsupported host OS for USB-SSH address config: $(uname -s)" >&2
		return 1
		;;
	esac
}

ping_usb_ssh_target() {
	local iface="$1"
	local addr="${USB_SSH_ADDR:-192.168.55.1}"
	case "$(usb_ssh_host_os)" in
	darwin) ping -c 1 -t 2 -b "$iface" "$addr" ;;
	linux) ping -c 1 -W 2 -I "$iface" "$addr" ;;
	windows)
		usb_ssh_windows_ps1 -Action ping \
			-HostAddress "$USB_SSH_HOST_ADDR" \
			-TargetAddress "$addr"
		;;
	*) return 1 ;;
	esac
}

# Background sysrq reboot; remote shell exits immediately (for make reboot / push-app).
USB_SSH_SYSRQ_REBOOT_CMD='sh -c "(sleep 1; sync; if [ -w /proc/sysrq-trigger ]; then echo 1 >/proc/sys/kernel/sysrq 2>/dev/null; echo b >/proc/sysrq-trigger; elif [ -x /usr/libexec/hmi/shutdown.sh ]; then /usr/libexec/hmi/shutdown.sh reboot; fi) >/dev/console 2>&1 & exit 0"'

# Reachability for registered remote SSH (MODE=SSH) or EMU hostfwd (host:port).
ping_remote_ssh_target() {
	local addr="$1"
	if is_emulator_ssh_endpoint "$addr" || [[ "$addr" == *:* ]]; then
		ssh_endpoint_reachable "$addr"
		return $?
	fi
	case "$(usb_ssh_host_os)" in
	darwin) ping -c 1 -t 2 "$addr" ;;
	linux) ping -c 1 -W 2 "$addr" ;;
	windows) ping -n 1 -w 2000 "$addr" >/dev/null 2>&1 ;;
	*) ping -c 1 "$addr" >/dev/null 2>&1 || ping -n 1 "$addr" >/dev/null 2>&1 ;;
	esac
}

remote_ssh_run() {
	local target_addr="$1"
	shift
	local target_user="${USB_SSH_USER:-root}"
	local ssh_pass="${USB_SSH_PASS:-rockchip}"
	local -a ssh_opts=(
		-o ConnectTimeout=5
		-o StrictHostKeyChecking=accept-new
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
	)

	require_sshpass
	parse_ssh_endpoint "$target_addr" || {
		echo "ERROR: invalid SSH endpoint: $target_addr" >&2
		return 1
	}
	ssh_opts+=(-p "$_SSH_PORT")
	sshpass -p "$ssh_pass" ssh "${ssh_opts[@]}" "$target_user@$_SSH_HOST" "$@"
}

remote_ssh_schedule_sysrq_reboot() {
	local target_addr="$1"
	echo "ssh ${USB_SSH_USER:-root}@${target_addr} sysrq reboot"
	remote_ssh_run "$target_addr" "$USB_SSH_SYSRQ_REBOOT_CMD" || true
}

usb_ssh_run() {
	local iface="$1"
	shift
	local target_addr="${USB_SSH_ADDR:-192.168.55.1}"
	local target_user="${USB_SSH_USER:-root}"
	local ssh_pass="${USB_SSH_PASS:-rockchip}"
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
	echo "ssh ${USB_SSH_USER:-root}@${USB_SSH_ADDR:-192.168.55.1} sysrq reboot"
	usb_ssh_run "$iface" "$USB_SSH_SYSRQ_REBOOT_CMD" || true
}

# Run remote command after brief delay in background; SSH returns without waiting for reset.
usb_ssh_schedule_remote() {
	local iface="$1" remote_cmd="$2"
	local remote_shell

	printf -v remote_shell 'sh -c "(sleep 1; %s) >/dev/console 2>&1 & exit 0"' "$remote_cmd"
	echo "ssh ${USB_SSH_USER:-root}@${USB_SSH_ADDR:-192.168.55.1} $remote_cmd"
	usb_ssh_run "$iface" "$remote_shell" || true
}
