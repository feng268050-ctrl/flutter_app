#!/usr/bin/env bash
# List USB-SSH (ECM/RNDIS gadget) devices for make devices / push-app / reboot / reboot-loader.
# Hosts: macOS, Linux, Windows (Git Bash/MSYS2 + PowerShell helper).
# Output: TSV rows — MODE, SN, LocationID, IFACE, IP, USB
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-common.sh
source "$ROOT/scripts/usb-ssh-common.sh"

USB_SSH_ADDR="${USB_SSH_ADDR:-192.168.55.1}"
USB_SSH_MODE="USB-SSH"
USB_MTP_MODE="USB-MTP"
USB_SSH_FS=$'\t'
# g_ether plug-ssh (usb-plug-ssh-start.sh); MTP uses 0011 — must not count as USB-SSH.
GADGET_VID="${USB_GADGET_VID:-2207}"
GADGET_PID="${USB_GADGET_PID:-0019}"
MTP_PID="${USB_MTP_PID:-0011}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# sn loc iface [usb]
usb_ssh_row() {
	local sn="$1" loc="$2" iface="$3" usb="${4:--}"
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$USB_SSH_MODE" "$sn" "$loc" "$iface" "$USB_SSH_ADDR" "$usb"
}

# MTP gadget: visible in make devices, never selected for SSH/push/upgrade.
usb_mtp_row() {
	local sn="$1" loc="$2" usb="${3:--}"
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$USB_MTP_MODE" "$sn" "$loc" "-" "-" "$usb"
}

ensure_host_addr_on_iface() {
	configure_usb_ssh_host_addr "$1"
}

fetch_board_identity_via_ssh() {
	local iface="$1"
	local addr="$USB_SSH_ADDR"
	local -a ssh_opts=(
		-o ConnectTimeout=3
		-o StrictHostKeyChecking=no
		-o UserKnownHostsFile=/dev/null
		-o LogLevel=ERROR
	)

	require_ssh_identity "$ROOT" || return 1
	ensure_host_addr_on_iface "$iface" || return 1
	ping_usb_ssh_target "$iface" >/dev/null 2>&1 || return 1
	while IFS= read -r opt; do
		[[ -n "$opt" ]] && ssh_opts+=("$opt")
	done < <(usb_ssh_bind_pair "$iface")
	remote_device_identity_via_ssh lws_ssh_with_opts "$ROOT" "${ssh_opts[@]}" "root@${addr}"
}

enrich_usb_ssh_rows() {
	# Prefer live board SN over host USB iSerial (gadget load may lag identity).
	# USB-MTP has no SSH — pass through without enrich.
	local mode sn loc iface addr usb pair chip
	while IFS=$'\t' read -r mode sn loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		if [[ "$mode" == "$USB_MTP_MODE" ]]; then
			printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mode" "$sn" "$loc" "-" "-" "${usb:--}"
			continue
		fi
		if [[ "$iface" != "-" && -n "$iface" ]]; then
			pair="$(fetch_board_identity_via_ssh "$iface" || true)"
			if [[ -n "$pair" ]]; then
				IFS=$'\t' read -r sn chip <<<"$pair"
			fi
		fi
		[[ -n "$sn" ]] || sn="-"
		printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$mode" "$sn" "$loc" "$iface" "$addr" "$usb"
	done
}

linux_iface_for_usb_sysfs() {
	local usb_path="$1" net_path
	net_path="$(find "$usb_path" -mindepth 1 -maxdepth 6 -path '*/net/*' -type d 2>/dev/null | head -1)"
	[ -n "$net_path" ] || return 1
	basename "$net_path"
}

linux_usb_path_for_net() {
	local net="$1" dev cur
	dev="$(readlink -f "/sys/class/net/$net/device" 2>/dev/null || true)"
	[ -n "$dev" ] || return 1
	cur="$dev"
	while [ "$cur" != "/" ]; do
		if [ -f "$cur/idVendor" ] && [ -f "$cur/idProduct" ]; then
			printf '%s\n' "$cur"
			return 0
		fi
		cur="$(dirname "$cur")"
	done
	return 1
}

linux_usb_matches_gadget() {
	local usb_path="$1" vid pid
	vid="$(cat "$usb_path/idVendor" 2>/dev/null || echo "")"
	pid="$(cat "$usb_path/idProduct" 2>/dev/null || echo "")"
	# Never treat MTP as USB-SSH (same Rockchip VID, different PID).
	[[ "$vid" == "$GADGET_VID" && "$pid" == "$MTP_PID" ]] && return 1
	if [[ "$vid" == "$GADGET_VID" ]]; then
		case "$GADGET_PID" in
		"" | "*" | any) return 0 ;;
		esac
		[[ "$pid" == "$GADGET_PID" ]] && return 0
	fi
	# Linux ECM often enumerates as RNDIS/Ethernet Gadget (same as macOS).
	[[ "$vid" == "0525" && "$pid" == "a4a2" ]] && return 0
	return 1
}

linux_usb_is_mtp() {
	local usb_path="$1" vid pid
	vid="$(cat "$usb_path/idVendor" 2>/dev/null || echo "")"
	pid="$(cat "$usb_path/idProduct" 2>/dev/null || echo "")"
	[[ "$vid" == "$GADGET_VID" && "$pid" == "$MTP_PID" ]]
}

linux_list_usb_ssh() {
	local usb_dev net usb_path vid pid serial loc iface seen="" usb
	for usb_dev in /sys/bus/usb/devices/*; do
		[ -f "$usb_dev/idVendor" ] || continue
		serial="$(cat "$usb_dev/serial" 2>/dev/null || true)"
		[[ -n "$serial" ]] || serial="-"
		loc="$(basename "$usb_dev")"
		vid="$(cat "$usb_dev/idVendor" 2>/dev/null || echo "")"
		pid="$(cat "$usb_dev/idProduct" 2>/dev/null || echo "")"
		usb="0x${vid}:0x${pid}"
		case " $seen " in
		*" $loc "*) continue ;;
		esac
		if linux_usb_is_mtp "$usb_dev"; then
			seen="$seen $loc"
			usb_mtp_row "$serial" "$loc" "$usb"
			continue
		fi
		linux_usb_matches_gadget "$usb_dev" || continue
		seen="$seen $loc"
		iface="$(linux_iface_for_usb_sysfs "$usb_dev" 2>/dev/null || echo "-")"
		usb_ssh_row "$serial" "$loc" "$iface" "$usb"
	done

	for net in /sys/class/net/*; do
		[ -d "$net" ] || continue
		iface="$(basename "$net")"
		[[ "$iface" == lo ]] && continue
		usb_path="$(linux_usb_path_for_net "$iface" 2>/dev/null || true)"
		[ -n "$usb_path" ] || continue
		linux_usb_matches_gadget "$usb_path" || continue
		loc="$(basename "$usb_path")"
		case " $seen " in
		*" $loc "*) continue ;;
		esac
		seen="$seen $loc"
		serial="$(cat "$usb_path/serial" 2>/dev/null || true)"
		[[ -n "$serial" ]] || serial="-"
		vid="$(cat "$usb_path/idVendor" 2>/dev/null || echo "")"
		pid="$(cat "$usb_path/idProduct" 2>/dev/null || echo "")"
		usb_ssh_row "$serial" "$loc" "$iface" "0x${vid}:0x${pid}"
	done
}

macos_list_usb_ssh() {
	local python=python3
	command -v "$python" >/dev/null 2>&1 || return 0
	"$python" - "$GADGET_VID" "$GADGET_PID" "$MTP_PID" "$USB_SSH_ADDR" "$USB_SSH_MODE" "$USB_MTP_MODE" <<'PY'
import hashlib, re, subprocess, sys

vid_want = sys.argv[1].lower().zfill(4)
pid_want = sys.argv[2].lower().zfill(4)
mtp_pid = sys.argv[3].lower().zfill(4)
addr = sys.argv[4]
ssh_mode = sys.argv[5]
mtp_mode = sys.argv[6]

def pid_matches_ssh(pid_hex: str) -> bool:
    if pid_want in ("", "*", "any"):
        # Still exclude MTP when wildcard VID match is enabled.
        return pid_hex.lower() != mtp_pid
    return pid_hex.lower() == pid_want

def networksetup_iface_for_port(port_substr: str) -> str:
    try:
        text = subprocess.check_output(
            ["networksetup", "-listallhardwareports"],
            text=True,
            errors="replace",
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "-"
    port = ""
    for line in text.splitlines():
        if line.startswith("Hardware Port:"):
            port = line.removeprefix("Hardware Port:").strip()
        elif line.startswith("Device:") and port_substr.lower() in port.lower():
            return line.split(":", 1)[1].strip()
    return "-"

def iface_for_mac(mac: str) -> str:
    try:
        text = subprocess.check_output(
            ["ifconfig", "-a"],
            text=True,
            errors="replace",
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "-"
    iface = ""
    for line in text.splitlines():
        m_iface = re.match(r"^([a-zA-Z0-9]+):", line)
        if m_iface:
            iface = m_iface.group(1)
            continue
        m_mac = re.match(r"^\s+ether\s+([0-9a-fA-F:]+)", line)
        if iface and m_mac and m_mac.group(1).lower() == mac.lower():
            return iface
    return "-"

def iter_gadget_chunks(text: str):
    for m in re.finditer(
        r"\+\-o ([^\n]*?)\s+<class IOUSBHostDevice[^>]*>",
        text,
    ):
        yield m.group(1), text[m.start() : m.start() + 3000]

def parse_vendor_product(chunk: str):
    vid = None
    pid = None
    m_vid = re.search(r'"idVendor"\s*=\s*0x([0-9a-fA-F]+)', chunk)
    if m_vid:
        vid = m_vid.group(1).lower()
    else:
        m_vid = re.search(r'"idVendor"\s*=\s*(\d+)', chunk)
        if m_vid:
            vid = format(int(m_vid.group(1)), "x")
    m_pid = re.search(r'"idProduct"\s*=\s*0x([0-9a-fA-F]+)', chunk)
    if m_pid:
        pid = m_pid.group(1).lower()
    else:
        m_pid = re.search(r'"idProduct"\s*=\s*(\d+)', chunk)
        if m_pid:
            pid = format(int(m_pid.group(1)), "x")
    return (
        vid.zfill(4) if vid is not None else None,
        pid.zfill(4) if pid is not None else None,
    )

def classify(name: str, chunk: str):
    """Return USB-SSH / USB-MTP / None.

    MTP iProduct is \"LWS Storage\"; plug-ssh is \"LWS HMI\" — classify by PID.
    """
    vid, pid = parse_vendor_product(chunk)
    if vid == vid_want and pid == mtp_pid:
        return mtp_mode
    if vid == vid_want and pid and pid_matches_ssh(pid):
        return ssh_mode
    # Legacy Linux ECM as RNDIS/Ethernet Gadget on macOS.
    if vid == "0525" and pid == "a4a2":
        return ssh_mode
    if "RNDIS" in name and "Gadget" in name:
        return ssh_mode
    m_prod = re.search(r'"USB Product Name"\s*=\s*"([^"]+)"', chunk)
    if m_prod:
        prod = m_prod.group(1)
        if "RNDIS" in prod and "Gadget" in prod:
            return ssh_mode
    return None

def iface_for_chunk(name: str, chunk: str, text: str) -> str:
    m_bsd = re.search(r'"BSD Name"\s*=\s*"(en[^"]+)"', chunk)
    if m_bsd:
        return m_bsd.group(1)
    m_serial = re.search(r'"USB Serial Number"\s*=\s*"([^"]+)"', chunk)
    if m_serial:
        digest = hashlib.md5(m_serial.group(1).strip().encode()).hexdigest()
        host_mac = "02:12:" + ":".join(digest[i : i + 2] for i in range(0, 8, 2))
        iface = iface_for_mac(host_mac)
        if iface != "-":
            return iface
    m_loc = re.search(r'"locationID"\s*=\s*0x([0-9a-fA-F]+)', chunk)
    loc = m_loc.group(1).upper() if m_loc else ""
    if loc:
        for sub in re.split(r"\n(?=\s+\+-o )", text):
            if loc.lower() not in sub.lower():
                continue
            m2 = re.search(r'"BSD Name"\s*=\s*"(en[^"]+)"', sub)
            if m2:
                return m2.group(1)
    if "RNDIS" in name:
        iface = networksetup_iface_for_port("RNDIS/Ethernet Gadget")
        if iface != "-":
            return iface
    return "-"

text = subprocess.check_output(["ioreg", "-p", "IOUSB", "-l", "-w", "0"], text=True, errors="replace")

gadget_blocks = []
for name, chunk in iter_gadget_chunks(text):
    mode = classify(name, chunk)
    if mode:
        gadget_blocks.append((mode, name, chunk))

if not gadget_blocks:
    sys.exit(0)

seen = set()
for mode, name, chunk in gadget_blocks:
    m_serial = re.search(r'"USB Serial Number"\s*=\s*"([^"]+)"', chunk)
    m_loc = re.search(r'"locationID"\s*=\s*0x([0-9a-fA-F]+)', chunk)
    vid, pid = parse_vendor_product(chunk)
    serial = m_serial.group(1).strip() if m_serial and m_serial.group(1).strip() else "-"
    loc = m_loc.group(1).upper() if m_loc else "-"
    identity = (mode, serial, loc)
    if identity in seen:
        continue
    seen.add(identity)
    usb = f"0x{vid}:0x{pid}" if vid and pid else "-"
    if mode == mtp_mode:
        print(f"{mode}\t{serial}\t{loc}\t-\t-\t{usb}")
        continue
    iface = iface_for_chunk(name, chunk, text)
    print(f"{mode}\t{serial}\t{loc}\t{iface}\t{addr}\t{usb}")
PY
}

# After remplug, macOS often creates en* without 192.168.55.2 until setup.
# Prefer already-addressed ifaces; else resolve RNDIS/LWS hardware ports.
darwin_gadget_ifaces() {
	local en port="" device=""
	for en in $(ifconfig -l 2>/dev/null); do
		[[ "$en" == en* ]] || continue
		if ifconfig "$en" 2>/dev/null | grep -qE 'inet 192\.168\.55\.'; then
			printf '%s\n' "$en"
		fi
	done
	command -v networksetup >/dev/null 2>&1 || return 0
	while IFS= read -r line; do
		case "$line" in
		"Hardware Port:"*)
			port="${line#Hardware Port: }"
			port="${port#"${port%%[![:space:]]*}"}"
			;;
		"Device:"*)
			device="${line#Device: }"
			device="${device#"${device%%[![:space:]]*}"}"
			case "$port" in
			*[Rr][Nn][Dd][Ii][Ss]* | *[Gg]adget* | *LWS* | *[Ii]nnohi*)
				[[ -n "$device" ]] && printf '%s\n' "$device"
				;;
			esac
			port=""
			device=""
			;;
		esac
	done < <(networksetup -listallhardwareports 2>/dev/null || true)
}

windows_list_usb_ssh() {
	# PowerShell emits full TSV rows (MODE SN LocationID IFACE IP USB).
	usb_ssh_windows_ps1 \
		-Action list \
		-Vid "$GADGET_VID" \
		-PidSsh "$GADGET_PID" \
		-PidMtp "$MTP_PID" \
		-TargetAddress "$USB_SSH_ADDR" 2>/dev/null || true
}

network_reachable_usb_ssh() {
	local addr="$USB_SSH_ADDR" iface="" serial="-" pass loc="-" candid
	case "$(usb_ssh_host_os)" in
	darwin)
		while IFS= read -r candid; do
			[[ -n "$candid" ]] || continue
			configure_usb_ssh_host_addr "$candid" 2>/dev/null || true
			if ping_usb_ssh_target "$candid" >/dev/null 2>&1; then
				iface="$candid"
				break
			fi
		done < <(darwin_gadget_ifaces | awk 'NF && !seen[$0]++')
		;;
	linux)
		local en
		for en in /sys/class/net/*; do
			en="$(basename "$en")"
			[[ "$en" == lo ]] && continue
			ip -4 addr show dev "$en" 2>/dev/null | grep -qE 'inet 192\.168\.55\.' || continue
			if ping -c 1 -W 1 -I "$en" "$addr" >/dev/null 2>&1; then
				iface="$en"
				break
			fi
		done
		;;
	windows)
		while IFS=$'\t' read -r _mode _sn _loc candid _ip _usb; do
			[[ "$_mode" == "$USB_SSH_MODE" ]] || continue
			[[ -n "$candid" && "$candid" != "-" ]] || continue
			configure_usb_ssh_host_addr "$candid" 2>/dev/null || true
			if ping_usb_ssh_target "$candid" >/dev/null 2>&1; then
				iface="$candid"
				loc="$_loc"
				break
			fi
		done < <(windows_list_usb_ssh || true)
		;;
	esac
	[[ -n "$iface" ]] || return 1
	if require_ssh_identity "$ROOT" 2>/dev/null; then
		local -a ssh_opts=(
			-o ConnectTimeout=2
			-o StrictHostKeyChecking=no
			-o UserKnownHostsFile=/dev/null
			-o LogLevel=ERROR
		)
		while IFS= read -r opt; do
			[[ -n "$opt" ]] && ssh_opts+=("$opt")
		done < <(usb_ssh_bind_pair "$iface")
		serial="$(remote_device_identity_via_ssh lws_ssh_with_opts "$ROOT" "${ssh_opts[@]}" \
			"root@${addr}" || printf '%s\t%s\n' '-' '-')"
		IFS=$'\t' read -r sn chip <<<"$serial"
		[[ -n "$sn" ]] || sn="-"
		[[ -n "$chip" ]] || chip="-"
		usb_ssh_row "$sn" "$loc" "$iface" "-"
	else
		usb_ssh_row "-" "$loc" "$iface" "-"
	fi
}

list_usb_ssh_devices() {
	local rows=""
	case "$(usb_ssh_host_os)" in
	linux) rows="$(linux_list_usb_ssh || true)" ;;
	darwin) rows="$(macos_list_usb_ssh || true)" ;;
	windows) rows="$(windows_list_usb_ssh || true)" ;;
	esac
	if [[ -z "$rows" ]]; then
		rows="$(network_reachable_usb_ssh || true)"
	fi
	[[ -n "$rows" ]] || return 0
	if [[ -n "${USB_SSH_SKIP_ENRICH:-}" ]]; then
		printf '%s\n' "$rows"
	else
		enrich_usb_ssh_rows <<<"$rows"
	fi
}

usb_ssh_device_count() {
	list_usb_ssh_devices | awk -F'\t' '$1=="USB-SSH"{n++} END{print n+0}'
}

select_usb_ssh_device() {
	local sn_sel pick_iface
	local -a rows=() row mode sn loc iface addr usb pair chip
	sn_sel="$(device_select_sn)"
	pick_iface="${IFACE:-}"
	while IFS="$USB_SSH_FS" read -r mode sn loc iface addr usb; do
		[[ -n "$mode" ]] || continue
		[[ "$mode" == "$USB_SSH_MODE" ]] || continue
		rows+=("${mode}${USB_SSH_FS}${sn}${USB_SSH_FS}${loc}${USB_SSH_FS}${iface}${USB_SSH_FS}${addr}${USB_SSH_FS}${usb}")
	done < <(list_usb_ssh_devices)

	if [[ ${#rows[@]} -eq 0 ]]; then
		return 1
	fi

	if [[ -n "$pick_iface" ]]; then
		for row in "${rows[@]}"; do
			IFS="$USB_SSH_FS" read -r mode sn loc iface addr usb <<<"$row"
			[[ "$iface" == "$pick_iface" ]] || continue
			printf '%s\n' "$loc" "$iface" "$addr"
			return 0
		done
		die "IFACE=$pick_iface not found (make devices)"
	fi

	if [[ -n "$sn_sel" && "$sn_sel" != "-" ]]; then
		for row in "${rows[@]}"; do
			IFS="$USB_SSH_FS" read -r mode sn loc iface addr usb <<<"$row"
			# SN= matches SN or LocationID.
			if [[ "$sn" == "$sn_sel" || "$loc" == "$sn_sel" ]]; then
				printf '%s\n' "$loc" "$iface" "$addr"
				return 0
			fi
			if [[ "$iface" != "-" && -n "$iface" ]]; then
				pair="$(fetch_board_identity_via_ssh "$iface" || true)"
				if [[ -n "$pair" ]]; then
					IFS=$'\t' read -r sn chip <<<"$pair"
					if [[ "$sn" == "$sn_sel" ]]; then
						printf '%s\n' "$loc" "$iface" "$addr"
						return 0
					fi
				fi
			fi
		done
		die "SN=$sn_sel not found in USB-SSH devices (make devices)"
	fi

	if [[ ${#rows[@]} -gt 1 ]]; then
		die "${#rows[@]} USB-SSH devices — set SN= or IFACE= (see make devices)"
	fi

	IFS="$USB_SSH_FS" read -r mode sn loc iface addr usb <<<"${rows[0]}"
	[[ "$iface" != "-" && -n "$iface" ]] || die "USB-SSH: no host IFACE (plug USB OTG; board: /usr/libexec/usb/usb-plug-ssh-start.sh)"
	printf '%s\n' "$loc" "$iface" "$addr"
}

case "${1:-}" in
""|--tsv)
	list_usb_ssh_devices
	;;
--select)
	# When SN= is set, host USB iSerial is often "-" (macOS RNDIS); enrich via SSH like make devices.
	if [[ -z "$(device_select_sn)" ]]; then
		USB_SSH_SKIP_ENRICH=1
	fi
	select_usb_ssh_device
	;;
*)
	die "usage: $0 [--tsv|--select]"
	;;
esac
