#!/usr/bin/env bash
# Boot P3.2 guest: same device Image + rootfs.img + sim_virt oem via QEMU.
#
# Default guest hardware is aligned with oem/boards/sim (not a half-configured box):
#   - 3× virtio-net with fixed MACs → eth0 / wlan0 / eth1 (debug) via systemd .link
#   - Darwin: eth0 vmnet (camera) + wlan0 Android-like SLIRP 10.0.2.16 + eth1 vmnet-host + ethssh hostfwd
#   - USB xHCI + auto passthrough of USB-serial / BT when host devices are present
#   - virtio-sound → host CoreAudio (macOS) / Pulse|ALSA (Linux)
#
# Env overrides:
#   EMULATOR_MEM EMULATOR_CPU EMULATOR_CPU_MODEL EMULATOR_CMDLINE EMULATOR_QEMU_EXTRA
#   EMULATOR_NET=auto|vmnet|user   (default auto)
#   EMULATOR_ETH0_IFACE=en9        (host NIC for IP camera — vmnet-bridged; auto USB LAN)
#   EMULATOR_ETH0_BRIDGE=auto|off  (auto=bridged when iface found; off=skip camera bridge)
#   EMULATOR_USB=auto|off|VID:PID[,VID:PID...]
#
# Apple vmnet-* needs root (Homebrew qemu lacks com.apple.vm.networking). The launcher
# re-runs QEMU under `sudo -E` when any vmnet netdev is configured.
#   EMULATOR_SSH_PORT=2222         (SSH hostfwd; always enabled; auto-bumps if busy)
#   EMULATOR_HTTP_PORT=5580        (LAN HTTP :5580 hostfwd; auto-bumps if busy)
#   EMULATOR_GL is ignored — host VirGL is required (virtio-gpu-gl).
#   EMULATOR_XRES=1536 EMULATOR_YRES=960  (defaults; virt display, not panel 800×1280)
#   QEMU=/path/to/qemu-system-aarch64  (prefer qemu-virgl keg on macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output/firmware/emulator"
MESA_VIRGL_HOST="$ROOT/prebuilt/emulator-swgl"
ACTION="${1:-start}"

# Fixed MACs — rootfs systemd .link renames; on real board these MACs never appear.
MAC_ETH0="52:54:00:12:e0:00"
MAC_WLAN0="52:54:00:12:a0:00"
MAC_DBG="52:54:00:12:d0:00"
# Extra SLIRP NIC on vmnet builds — hostfwd only (not in net_roles).
MAC_SSH="52:54:00:12:22:22"
ENDPOINT_FILE="$OUT/ssh-endpoint"

# Android Emulator Wi‑Fi address space (Studio 36.5+): guest 10.0.2.16,
# host/gateway alias 10.0.2.2, DNS 10.0.2.3. Keep other SLIRP NICs off
# 10.0.2.0/24 so DHCP does not collide across multiple -netdev user.
# https://developer.android.com/studio/run/emulator-networking-address
SLIRP_WLAN_ANDROID="net=10.0.2.0/24,host=10.0.2.2,dns=10.0.2.3,dhcpstart=10.0.2.16"
SLIRP_ETH0_ISOLATED="net=10.0.3.0/24"
SLIRP_DBG_ISOLATED="net=10.0.4.0/24"
SLIRP_SSH_ISOLATED="net=10.0.5.0/24"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "emulator: $*"; }
warn() { echo "emulator: WARNING: $*" >&2; }

# shellcheck source=scripts/emulator-common.sh
source "$ROOT/scripts/emulator-common.sh"

stop_lws_emulator() {
	local pids pid
	pids="$(lws_emulator_pids | tr '\n' ' ')"
	pids="$(echo "$pids" | xargs)" # trim
	if [[ -z "$pids" ]]; then
		log "no running lws-hmi emulator"
		rm -f "$ENDPOINT_FILE"
		return 0
	fi
	log "stopping previous emulator: $pids"
	# shellcheck disable=SC2086
	if ! kill $pids 2>/dev/null; then
		# QEMU may be root when using Apple vmnet (sudo -E).
		warn "kill failed (process may be root) — trying sudo kill"
		# shellcheck disable=SC2086
		sudo kill $pids 2>/dev/null || true
	fi
	local i
	for i in 1 2 3 4 5 6 7 8 9 10; do
		pids="$(lws_emulator_pids | tr '\n' ' ')"
		pids="$(echo "$pids" | xargs)"
		[[ -z "$pids" ]] && break
		sleep 0.5
	done
	pids="$(lws_emulator_pids | tr '\n' ' ')"
	pids="$(echo "$pids" | xargs)"
	if [[ -n "$pids" ]]; then
		warn "force-killing: $pids"
		# shellcheck disable=SC2086
		kill -9 $pids 2>/dev/null || sudo kill -9 $pids 2>/dev/null || true
		sleep 0.5
	fi
	rm -f "$ENDPOINT_FILE"
}

write_ssh_endpoint() {
	local port="$1"
	mkdir -p "$OUT"
	printf '127.0.0.1:%s\n' "$port" >"$ENDPOINT_FILE"
}

tcp_port_free() {
	local port="$1"
	if command -v lsof >/dev/null 2>&1; then
		! lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
		return $?
	fi
	# Fallback: assume free
	return 0
}

pick_ssh_port() {
	local want="${EMULATOR_SSH_PORT:-2222}"
	local p
	for p in "$want" 2223 2224 2225 2226 2227 2228 2229 2230; do
		if tcp_port_free "$p"; then
			echo "$p"
			return 0
		fi
	done
	die "no free SSH hostfwd port (tried $want and 2223–2230); free the port or set EMULATOR_SSH_PORT="
}

# Device-local HTTP API (App DeviceLocalHttpServer on guest :5580).
pick_http_port() {
	local want="${EMULATOR_HTTP_PORT:-5580}"
	local p
	for p in "$want" 5581 5582 5583 5584 5585 5586 5587 5588 5589; do
		if tcp_port_free "$p"; then
			echo "$p"
			return 0
		fi
	done
	die "no free HTTP hostfwd port (tried $want and 5581–5589); free the port or set EMULATOR_HTTP_PORT="
}

find_qemu() {
	local c
	# want_gl arg kept for callers; qemu-virgl is preferred either way (a55 + optional VirGL).
	if [[ -n "${QEMU:-}" && -x "${QEMU}" ]]; then
		echo "$QEMU"
		return 0
	fi
	# Prefer qemu-virgl: stock Homebrew qemu lacks cortex-a55 and host VirGL.
	for c in \
		"$(brew --prefix qemu-virgl 2>/dev/null)/bin/qemu-system-aarch64" \
		/opt/homebrew/opt/qemu-virgl/bin/qemu-system-aarch64 \
		/usr/local/opt/qemu-virgl/bin/qemu-system-aarch64
	do
		if [[ -n "$c" && -x "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	c="$(ls -d /opt/homebrew/Cellar/qemu-virgl/*/bin/qemu-system-aarch64 2>/dev/null | tail -1 || true)"
	if [[ -n "$c" && -x "$c" ]]; then
		echo "$c"
		return 0
	fi
	for c in \
		"$(brew --prefix qemu 2>/dev/null)/bin/qemu-system-aarch64" \
		/opt/homebrew/opt/qemu/bin/qemu-system-aarch64 \
		/usr/local/opt/qemu/bin/qemu-system-aarch64
	do
		if [[ -n "$c" && -x "$c" ]]; then
			echo "$c"
			return 0
		fi
	done
	if command -v qemu-system-aarch64 >/dev/null 2>&1; then
		command -v qemu-system-aarch64
		return 0
	fi
	return 1
}

qemu_supports_vmnet() {
	local bin="$1"
	# Stock `-netdev help` omits vmnet; need a machine type (same as bridged probe).
	"$bin" -machine virt -netdev help 2>&1 | grep -q 'vmnet-shared' || return 1
	return 0
}

qemu_supports_host_gl() {
	local bin="$1"
	# Stock Homebrew qemu has no virtio-gpu-gl-*; qemu-virgl does.
	"$bin" -device help 2>&1 | grep -q 'virtio-gpu-gl-pci'
}

# Print "vvvv:pppp" lines (lowercase hex) for USB-serial / BT candidates.
# Darwin: prefer ioreg — system_profiler SPUSBDataType -xml is often empty on macOS 15+.
discover_usb_vid_pids() {
	python3 - <<'PY' 2>/dev/null || true
import plistlib, re, subprocess, sys

SERIAL = {
    (0x0403, 0x6001), (0x0403, 0x6010), (0x0403, 0x6011), (0x0403, 0x6014),
    (0x10C4, 0xEA60), (0x10C4, 0xEA61), (0x10C4, 0xEA70),
    (0x1A86, 0x7523), (0x1A86, 0x5523), (0x1A86, 0x55D4),
    (0x067B, 0x2303), (0x067B, 0x23A3),
    (0x04D8, 0x000A),
}
BT = {
    (0x0A12, 0x0001), (0x0B05, 0x17CB), (0x0BDA, 0x8771), (0x0BDA, 0xB733),
    (0x0CF3, 0xE300), (0x8087, 0x0A2A), (0x8087, 0x0AAA), (0x0A5C, 0x21E8),
}
WANT = SERIAL | BT
found = set()


def parse_id(v):
    if v is None:
        return None
    if isinstance(v, int):
        return v & 0xFFFF
    s = str(v).lower().replace("0x", "").split()[0]
    try:
        return int(s, 16)
    except ValueError:
        return None


def walk_plist(node):
    if isinstance(node, dict):
        vid = pid = None
        for k, val in node.items():
            kl = str(k).lower()
            if "vendor_id" in kl or kl == "idvendor":
                vid = val
            if ("product_id" in kl or kl == "idproduct") and "string" not in kl:
                pid = val
        a, b = parse_id(vid), parse_id(pid)
        if a is not None and b is not None and (a, b) in WANT:
            found.add(f"{a:04x}:{b:04x}")
        for val in node.values():
            walk_plist(val)
    elif isinstance(node, list):
        for item in node:
            walk_plist(item)


def discover_ioreg():
    try:
        out = subprocess.check_output(
            ["ioreg", "-p", "IOUSB", "-l", "-w0"],
            text=True,
            stderr=subprocess.DEVNULL,
            errors="replace",
        )
    except Exception:
        return
    for block in re.split(r"\+-o\s+", out):
        vid_m = re.search(r'"idVendor"\s*=\s*(\d+)', block)
        pid_m = re.search(r'"idProduct"\s*=\s*(\d+)', block)
        if not vid_m or not pid_m:
            continue
        a, b = int(vid_m.group(1)) & 0xFFFF, int(pid_m.group(1)) & 0xFFFF
        if (a, b) in WANT:
            found.add(f"{a:04x}:{b:04x}")


if sys.platform == "darwin":
    discover_ioreg()
    if not found:
        try:
            raw = subprocess.check_output(
                ["system_profiler", "SPUSBDataType", "-xml"],
                stderr=subprocess.DEVNULL,
            )
            walk_plist(plistlib.loads(raw))
        except Exception:
            pass
else:
    try:
        out = subprocess.check_output(["lsusb"], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        out = ""
    for m in re.finditer(r"\bID\s+([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\b", out):
        a, b = int(m.group(1), 16), int(m.group(2), 16)
        if (a, b) in WANT:
            found.add(f"{a:04x}:{b:04x}")

for item in sorted(found):
    print(item)
PY
}

build_usb_args() {
	USB_ARGS=()
	USB_ARGS+=(-device qemu-xhci,id=xhci)
	local mode="${EMULATOR_USB:-auto}"
	local ids=()
	local id vid pid
	case "$mode" in
	off | none | 0)
		log "USB passthrough disabled (EMULATOR_USB=$mode); xHCI only"
		return 0
		;;
	auto)
		while IFS= read -r id; do
			[[ -n "$id" ]] || continue
			ids+=("$id")
		done < <(discover_usb_vid_pids | sort -u)
		;;
	*)
		# EMULATOR_USB=0403:6001,0a12:0001
		IFS=',' read -r -a ids <<<"$mode"
		;;
	esac

	if [[ "${#ids[@]}" -eq 0 ]]; then
		warn "no USB-serial/BT device auto-detected — plug a dongle or set EMULATOR_USB=vid:pid"
		warn "guest Modbus/BT will fail until USB is passed through"
		return 0
	fi

	local n=0
	for id in "${ids[@]}"; do
		id="$(echo "$id" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
		[[ "$id" == *:* ]] || continue
		vid="${id%%:*}"
		pid="${id##*:}"
		USB_ARGS+=(-device "usb-host,vendorid=0x${vid},productid=0x${pid}")
		log "USB passthrough $vid:$pid (sim Modbus → /dev/ttyUSB0)"
		n=$((n + 1))
	done
	[[ "$n" -gt 0 ]] || warn "EMULATOR_USB set but no valid vid:pid parsed"
	if [[ "$n" -gt 0 ]]; then
		warn "if guest lacks /dev/ttyUSB0: quit apps using /dev/cu.usbserial-* then restart emulator"
	fi
}

qemu_supports_vmnet_bridged() {
	local bin="$1"
	"$bin" -machine virt -netdev help 2>&1 | grep -q 'vmnet-bridged'
}

# Host iface for product eth0 (dedicated IP camera link). Prefer EMULATOR_ETH0_IFACE;
# else auto-pick macOS "USB * LAN" / Ethernet Adapter (not Wi‑Fi / Thunderbolt Bridge).
resolve_camera_host_iface() {
	local want="${EMULATOR_ETH0_IFACE:-}"
	if [[ -n "$want" ]]; then
		if [[ "$(uname -s)" == Darwin ]] && ! ifconfig "$want" >/dev/null 2>&1; then
			die "EMULATOR_ETH0_IFACE=$want not found (ifconfig); plug the camera Ethernet / USB-LAN dongle"
		fi
		echo "$want"
		return 0
	fi
	[[ "$(uname -s)" == Darwin ]] || return 1
	# Parse networksetup blocks: Hardware Port + Device.
	local port="" dev="" best=""
	while IFS= read -r line; do
		case "$line" in
		"Hardware Port:"*)
			port="${line#Hardware Port: }"
			port="$(echo "$port" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
			;;
		"Device:"*)
			dev="${line#Device: }"
			dev="$(echo "$dev" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
			case "$port" in
			"USB "*"LAN"* | "USB LAN" | Ethernet | "Ethernet Adapter"*)
				case "$port" in
				*Thunderbolt* | *Wi-Fi* | *WiFi*) ;;
				*)
					if ifconfig "$dev" >/dev/null 2>&1; then
						# Prefer USB LAN over Apple Ethernet Adapter (en2/en3).
						case "$port" in
						USB*)
							echo "$dev"
							return 0
							;;
						*)
							[[ -z "$best" ]] && best="$dev"
							;;
						esac
					fi
					;;
				esac
				;;
			esac
			;;
		esac
	done < <(networksetup -listallhardwareports 2>/dev/null || true)
	[[ -n "$best" ]] || return 1
	echo "$best"
}

build_net_args() {
	NET_ARGS=()
	USES_VMNET=0
	local mode="${EMULATOR_NET:-auto}"
	local bin="$1"
	local os
	local cam_iface=""
	local eth0_desc=""
	local eth0_bridge="${EMULATOR_ETH0_BRIDGE:-auto}"
	os="$(uname -s)"
	SSH_PORT="${EMULATOR_SSH_PORT:-2222}"
	HTTP_PORT="${EMULATOR_HTTP_PORT:-5580}"

	if [[ "$mode" == auto ]]; then
		if [[ "$os" == Darwin ]] && qemu_supports_vmnet "$bin"; then
			mode=vmnet
		else
			mode=user
		fi
	fi

	cam_iface="$(resolve_camera_host_iface 2>/dev/null || true)"
	if [[ "$eth0_bridge" == off || "$eth0_bridge" == 0 || "$eth0_bridge" == none ]]; then
		if [[ -n "$cam_iface" ]]; then
			warn "EMULATOR_ETH0_BRIDGE=$eth0_bridge — not bridging $cam_iface (IP camera eth0 disabled)"
		fi
		cam_iface=""
	elif [[ -n "$cam_iface" ]] && qemu_supports_vmnet_bridged "$bin"; then
		eth0_desc="vmnet-bridged ifname=$cam_iface (host camera Ethernet → guest eth0)"
	elif [[ -n "$cam_iface" ]]; then
		warn "host camera iface $cam_iface found but QEMU lacks vmnet-bridged — install qemu-virgl"
		cam_iface=""
	fi

	SSH_PORT="$(pick_ssh_port)"
	if [[ "$SSH_PORT" != "${EMULATOR_SSH_PORT:-2222}" ]]; then
		warn "SSH hostfwd port ${EMULATOR_SSH_PORT:-2222} busy — using $SSH_PORT"
	fi
	HTTP_PORT="$(pick_http_port)"
	if [[ "$HTTP_PORT" != "${EMULATOR_HTTP_PORT:-5580}" ]]; then
		warn "HTTP hostfwd port ${EMULATOR_HTTP_PORT:-5580} busy — using $HTTP_PORT"
	fi
	# Same SLIRP NIC: SSH + LAN HTTP (:5580 DeviceLocalHttpServer) for Postman / tools.
	SSH_HOSTFWD="hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::${HTTP_PORT}-:5580"

	case "$mode" in
	vmnet)
		USES_VMNET=1
		log "network: vmnet — eth0=camera link, wlan0=Android-like SLIRP 10.0.2.16, eth1=debug, ethssh=SSH :${SSH_PORT} HTTP :${HTTP_PORT}"
		log "note: Apple vmnet needs admin — launcher will use sudo -E for QEMU"
		if [[ -n "$cam_iface" ]]; then
			log "eth0: $eth0_desc"
			NET_ARGS+=(
				-netdev "vmnet-bridged,id=n0,ifname=${cam_iface}"
				-device virtio-net-pci,netdev=n0,mac="$MAC_ETH0"
			)
		else
			warn "no host camera Ethernet (set EMULATOR_ETH0_IFACE=enX after plugging USB-LAN) — eth0 uses vmnet-shared (IPC will fail without camera on that LAN)"
			NET_ARGS+=(
				-netdev vmnet-shared,id=n0
				-device virtio-net-pci,netdev=n0,mac="$MAC_ETH0"
			)
		fi
		# wlan0: SLIRP (not vmnet-shared) so DHCP matches Android Emulator Wi‑Fi.
		NET_ARGS+=(
			-netdev "user,id=n1,${SLIRP_WLAN_ANDROID}"
			-device virtio-net-pci,netdev=n1,mac="$MAC_WLAN0"
			-netdev vmnet-host,id=n2
			-device virtio-net-pci,netdev=n2,mac="$MAC_DBG"
			-netdev "user,id=n_ssh,restrict=on,${SLIRP_SSH_ISOLATED},${SSH_HOSTFWD}"
			-device virtio-net-pci,netdev=n_ssh,mac="$MAC_SSH"
		)
		log "wlan0: Android-like SLIRP (guest 10.0.2.16 gw/host 10.0.2.2 dns 10.0.2.3)"
		log "SSH: ssh -p ${SSH_PORT} root@127.0.0.1 (MODE=EMU)"
		log "HTTP: http://127.0.0.1:${HTTP_PORT}/ (guest :5580; HMI must be running)"
		;;
	user)
		log "network: user/SLIRP — wlan0 Android-like 10.0.2.16 + ethssh SSH :${SSH_PORT} HTTP :${HTTP_PORT}; eth0=camera"
		if [[ -n "$cam_iface" ]]; then
			USES_VMNET=1
			log "eth0: $eth0_desc (overrides user-net for camera NIC; needs sudo -E)"
			NET_ARGS+=(
				-netdev "vmnet-bridged,id=n0,ifname=${cam_iface}"
				-device virtio-net-pci,netdev=n0,mac="$MAC_ETH0"
			)
		else
			warn "no host camera Ethernet — eth0 restrict SLIRP only (plug USB-LAN + EMULATOR_ETH0_IFACE=…)"
			NET_ARGS+=(
				-netdev "user,id=n0,restrict=on,${SLIRP_ETH0_ISOLATED}"
				-device virtio-net-pci,netdev=n0,mac="$MAC_ETH0"
			)
		fi
		NET_ARGS+=(
			-netdev "user,id=n1,${SLIRP_WLAN_ANDROID}"
			-device virtio-net-pci,netdev=n1,mac="$MAC_WLAN0"
			-netdev "user,id=n2,restrict=on,${SLIRP_DBG_ISOLATED}"
			-device virtio-net-pci,netdev=n2,mac="$MAC_DBG"
			-netdev "user,id=n_ssh,restrict=on,${SLIRP_SSH_ISOLATED},${SSH_HOSTFWD}"
			-device virtio-net-pci,netdev=n_ssh,mac="$MAC_SSH"
		)
		log "wlan0: Android-like SLIRP (guest 10.0.2.16 gw/host 10.0.2.2 dns 10.0.2.3)"
		log "SSH: ssh -p ${SSH_PORT} root@127.0.0.1 (MODE=EMU)"
		log "HTTP: http://127.0.0.1:${HTTP_PORT}/ (guest :5580; HMI must be running)"
		;;
	bridge)
		die "EMULATOR_NET=bridge (Linux br0) is not supported as default on this project.
On macOS set EMULATOR_ETH0_IFACE=enX (vmnet-bridged). On Linux use EMULATOR_QEMU_EXTRA with tap/bridge."
		;;
	*)
		die "unknown EMULATOR_NET=$mode (use auto|vmnet|user)"
		;;
	esac
	write_ssh_endpoint "$SSH_PORT"
}

build_audio_args() {
	AUDIO_ARGS=()
	AUDIO_DESC="none"
	local os bin="$1"
	os="$(uname -s)"
	# Playback-only (streams=1): default virtio-sound also opens a capture
	# stream; CoreAudio often fails with "Could not create … virtio-sound.in".
	case "$os" in
	Darwin)
		AUDIO_ARGS=(
			-audiodev coreaudio,id=lws_audio
			-device virtio-sound-pci,audiodev=lws_audio,streams=1
		)
		AUDIO_DESC="virtio-sound (playback) + coreaudio"
		;;
	*)
		if "$bin" -audiodev help 2>&1 | grep -qx 'pa'; then
			AUDIO_ARGS=(
				-audiodev pa,id=lws_audio
				-device virtio-sound-pci,audiodev=lws_audio,streams=1
			)
			AUDIO_DESC="virtio-sound (playback) + pulse"
		elif "$bin" -audiodev help 2>&1 | grep -qx 'alsa'; then
			AUDIO_ARGS=(
				-audiodev alsa,id=lws_audio
				-device virtio-sound-pci,audiodev=lws_audio,streams=1
			)
			AUDIO_DESC="virtio-sound (playback) + alsa"
		else
			warn "no host audiodev (pa/alsa) — guest sound disabled"
			AUDIO_ARGS=(-audio driver=none)
			AUDIO_DESC="none"
		fi
		;;
	esac
}

print_hw_map() {
	cat <<EOF
emulator: hardware map (sim OEM contract)
  machine : virt + GICv3 + cpu ${CPU:-cortex-a55}
  memory  : ${MEM} MiB   smp=${SMP}
  disk0   : /dev/vda ← rootfs.img (same as device)
  disk1   : /dev/vdb ← sim_virt oem.img → /oem
  display : ${DISPLAY_DESC}
  nic eth0  MAC $MAC_ETH0  ← IP camera link (host Ethernet/USB-LAN → vmnet-bridged)
  nic wlan0 MAC $MAC_WLAN0 ← wifi.station (virtio; USB Wi-Fi dongle overrides when passed)
  nic eth1  MAC $MAC_DBG   ← debug (not in net_roles)
  nic ethssh               ← SSH hostfwd localhost:${SSH_PORT:-2222} + HTTP :${HTTP_PORT:-5580}→:5580
  audio   : ${AUDIO_DESC}
  usb     : xHCI + auto serial/BT passthrough (EMULATOR_USB=off to disable)
  mesa    : ${MESA_DESC}
  ssh     : ${SSH_PORT:+localhost:${SSH_PORT} (make devices MODE=EMU)}
  http    : ${HTTP_PORT:+localhost:${HTTP_PORT} → guest :5580 (Postman / LAN API)}
EOF
}

case "$ACTION" in
stop)
	stop_lws_emulator
	exit 0
	;;
status)
	if [[ -f "$OUT/manifest.txt" ]]; then
		cat "$OUT/manifest.txt"
	else
		echo "no emulator bundle — run: make build-emulator"
	fi
	pids="$(lws_emulator_pids || true)"
	if [[ -n "${pids:-}" ]]; then
		echo "running:"
		# shellcheck disable=SC2086
		ps -p $(echo "$pids" | tr '\n' ',') -o pid=,command= 2>/dev/null || echo "$pids"
	else
		echo "not running"
	fi
	exit 0
	;;
start) ;;
*)
	die "usage: $0 {start|stop|status}"
	;;
esac

MEM="${EMULATOR_MEM:-2048}"
# cortex-a55 ≈ RK356x; avoid -cpu max feature surprises on Apple HVF
# Default SMP=1: systemd 256 (sd-gens)/HVF races with smp>=2 hang after Welcome
# on this virt motherboard; override with EMULATOR_CPU=4 when debugging perf.
SMP="${EMULATOR_CPU:-1}"
CPU="${EMULATOR_CPU_MODEL:-cortex-a55}"
# Multi-board cmdline: lws.emulator=1 marks the sim/virt motherboard (same OS image).
# systemd.*_auto=no: sim lacks vsock/GPT-auto; overlay masks stock generators.
# random.trust_cpu=on: help first-boot getrandom; build-emulator also seeds machine-id
# into the emulator rootfs *copy* only.
CMDLINE="${EMULATOR_CMDLINE:-root=/dev/vda rootfstype=ext4 rw console=ttyAMA0 earlycon=pl011,0x9000000 lws.emulator=1 systemd.ssh_auto=no systemd.getty_auto=no systemd.gpt_auto=no random.trust_cpu=on}"
GL_MODE="${EMULATOR_GL:-host}"
case "$GL_MODE" in
host | auto) ;;
off)
	die "EMULATOR_GL=off removed — P3.2 emulator requires host VirGL (make setup-emulator-qemu)"
	;;
*)
	die "unknown EMULATOR_GL=$GL_MODE (use host|auto)"
	;;
esac

QEMU_BIN="$(find_qemu)" || die "qemu-system-aarch64 not found.
macOS (VirGL): make setup-emulator-qemu
  or: brew tap startergo/qemu-virgl && brew trust startergo/qemu-virgl && brew install startergo/qemu-virgl/qemu-virgl
Linux: install distro qemu with virgl, then QEMU=/path/to/qemu-system-aarch64 make emulator"

# Previous instance holds :2222 and an exclusive lock on rootfs.img.
if [[ -n "$(lws_emulator_pids || true)" ]]; then
	stop_lws_emulator
fi

if [[ ! -f "$OUT/manifest.txt" || ! -r "$OUT/Image" || ! -r "$OUT/rootfs.img" || ! -r "$OUT/oem.img" ]]; then
	log "emulator bundle incomplete — running build-emulator"
	bash "$ROOT/scripts/build-emulator.sh"
fi

[[ -r "$OUT/Image" ]] || die "missing $OUT/Image — make build-kernel"
[[ -r "$OUT/rootfs.img" ]] || die "missing $OUT/rootfs.img — make build-rootfs"
[[ -r "$OUT/oem.img" ]] || die "missing $OUT/oem.img"

# Stock Homebrew qemu lacks cortex-a55; fall back so EMULATOR_CPU_MODEL default still boots.
if [[ -z "${EMULATOR_CPU_MODEL:-}" ]] && ! "$QEMU_BIN" -cpu help 2>&1 | grep -qE '(^|[[:space:]])cortex-a55([[:space:]]|$)'; then
	CPU=cortex-a53
	warn "QEMU $QEMU_BIN has no cortex-a55 — using $CPU"
fi

# Emulator display size (independent of board panel). Default 1536×960 (~1.2×
# 1280×800) so HiDPI MacBook windows match physical panel width; keep in sync
# with oem/screens/virt. Override with EMULATOR_XRES / EMULATOR_YRES if needed.
EMU_XRES="${EMULATOR_XRES:-1536}"
EMU_YRES="${EMULATOR_YRES:-960}"

if ! qemu_supports_host_gl "$QEMU_BIN"; then
	die "QEMU lacks host VirGL ($QEMU_BIN). Run: make setup-emulator-qemu"
fi
[[ -d "$MESA_VIRGL_HOST/lib/dri" ]] || die "missing $MESA_VIRGL_HOST — run: make fetch-emulator-swgl"
[[ -f "$MESA_VIRGL_HOST/lib/libweston-14/gl-renderer.so" ]] \
	|| die "missing Mesa-patched Weston modules — run: make fetch-emulator-swgl"

GPU_ARGS=(-device "virtio-gpu-gl-pci,xres=${EMU_XRES},yres=${EMU_YRES}")
if [[ "$(uname -s)" == "Darwin" ]]; then
	DISPLAY_ARGS=(-display cocoa,gl=es)
else
	DISPLAY_ARGS=(-display gtk,gl=on)
fi
DISPLAY_DESC="virtio-gpu-gl ${EMU_XRES}×${EMU_YRES} + host VirGL"
MESA_DESC="9p lws_gl → $MESA_VIRGL_HOST"
FS_ARGS=(
	-fsdev "local,id=lws_gl,path=$MESA_VIRGL_HOST,security_model=none,readonly=on"
	-device virtio-9p-pci,fsdev=lws_gl,mount_tag=lws_gl
)

MACHINE_ARGS=(-machine virt,gic-version=3)
# Apple Hypervisor when available (qemu-virgl / modern qemu).
if [[ "$(uname -s)" == "Darwin" ]] && "$QEMU_BIN" -accel help 2>&1 | grep -q hvf; then
	MACHINE_ARGS=(-machine virt,gic-version=3,accel=hvf)
fi

build_net_args "$QEMU_BIN"
build_usb_args
build_audio_args "$QEMU_BIN"
log "qemu: $QEMU_BIN"
print_hw_map

QEMU_CMD=("$QEMU_BIN")
if [[ "${USES_VMNET:-0}" -eq 1 && "$(uname -s)" == Darwin ]]; then
	if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
		log "elevating QEMU with sudo -E (Apple vmnet requires root on Homebrew qemu)"
		QEMU_CMD=(sudo -E "$QEMU_BIN")
	fi
fi

# Do not exec: clear ssh-endpoint when QEMU exits (Ctrl-C / window close) so
# make devices does not keep a phantom MODE=EMU row.
cleanup_ssh_endpoint_on_exit() {
	rm -f "$ENDPOINT_FILE"
}
trap cleanup_ssh_endpoint_on_exit EXIT

# shellcheck disable=SC2086
"${QEMU_CMD[@]}" \
	"${MACHINE_ARGS[@]}" \
	-cpu "$CPU" \
	-m "$MEM" \
	-smp "$SMP" \
	-kernel "$OUT/Image" \
	-append "$CMDLINE" \
	-drive if=none,file="$OUT/rootfs.img",format=raw,id=rootdisk \
	-device virtio-blk-pci,drive=rootdisk,bootindex=1 \
	-drive if=none,file="$OUT/oem.img",format=raw,id=oemdisk \
	-device virtio-blk-pci,drive=oemdisk \
	"${GPU_ARGS[@]}" \
	-device virtio-keyboard-pci \
	-device virtio-tablet-pci \
	"${FS_ARGS[@]}" \
	"${NET_ARGS[@]}" \
	"${USB_ARGS[@]}" \
	"${AUDIO_ARGS[@]}" \
	-serial mon:stdio \
	"${DISPLAY_ARGS[@]}" \
	${EMULATOR_QEMU_EXTRA:-}
