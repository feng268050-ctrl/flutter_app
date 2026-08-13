#!/usr/bin/env bash
# Remote firmware upgrade (make upgrade).
# Transports:
#   SSH (USB-SSH / LAN) — host ephemeral HTTP serves tar.gz+.sig; device HMI downloads →
#     staged verify/extract/apply. SSH is control-plane only (trigger + TRANSFER_COMPLETE).
#   RockUSB Loader/Maskrom — upgrade_tool di of OTA-equivalent loose images (not uf factory.img)
# OEM_ONLY=1: oem partition only (SSH plain reboot via apply; RockUSB di oem only).
# MUST NOT stream images directly to partitions on SSH (stream path retired as default).
# Device MUST Ed25519-verify. RockUSB di is unsigned.
# MUST NOT invoke upgrade_tool uf / flash factory.img (RockUSB path uses di only).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve
# shellcheck source=scripts/factory-sku.sh
source "$ROOT/scripts/factory-sku.sh"

FIRMWARE="${FIRMWARE_DIR:-$ROOT/output/firmware}"
OTA_DIR="/userdata/ota"
PREFLIGHT_REMOTE="/usr/libexec/ab/ab-preflight.sh"
CMD_PATH="/run/hmi/upgrade-ota.cmd"
ARCHIVE_REMOTE="$OTA_DIR/ota-package.tar.gz"
OEM_ONLY="${OEM_ONLY:-0}"
# UPGRADE_PACKAGE= alternate tarball (skip make pack-ota). See upgrade-package-env.
# UPGRADE_TRANSPORT defaulted after .env load; optional: auto|ssh|rockusb

# Deprecated alias → OEM_IMG
if [[ -n "${UPGRADE_OEM_IMG+x}" && -z "${OEM_IMG+x}" ]]; then
	OEM_IMG="${UPGRADE_OEM_IMG}"
	echo "WARNING: UPGRADE_OEM_IMG is deprecated; use OEM_IMG= instead" >&2
fi

# OEM_IMG unset → default to resolved oem.img when present.
# OEM_IMG="" (explicit empty) → skip oem (forbidden when OEM_ONLY=1).
# OEM_IMG=/path → use that path.
if [[ -z "${OEM_IMG+x}" ]]; then
	if [[ -r "$FACTORY_OEM_IMG" ]]; then
		OEM_IMG="$FACTORY_OEM_IMG"
	else
		OEM_IMG=""
	fi
fi

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Firmware upgrade over SSH staged package or RockUSB Loader/Maskrom.

SSH (default when a Linux USB-SSH / registered SSH target is selected):
  Ensures OTA tar.gz + .sig via pack-ota (unless UPGRADE_PACKAGE= + sibling .sig),
  starts an ephemeral HTTP server on the host, triggers the HMI to download the package
  (same path as cloud OTA), waits until archive+.sig have been fully GET (host send
  progress on stderr), then returns. Device verify/apply/reboot continue on the board;
  host does not wait for on-device apply or claim apply success. Allow inbound TCP on the bind
  IP if the OS firewall prompts (USB-SSH default bind 192.168.55.2).

RockUSB (when Loader/Maskrom is selected, or UPGRADE_TRANSPORT=rockusb):
  upgrade_tool di of OTA-equivalent images: boot + boot_b + rootfs_a + rootfs_b
  (+ optional oem). Maskrom: ul MiniLoader into RAM first. Does NOT uf factory.img
  and does NOT rewrite uboot / GPT / misc. Not product/SSH staged OTA (no tar.gz+.sig verify).

OEM_ONLY=1:
  oem partition only (SSH: staged verify-apply + plain reboot; RockUSB: di oem only).

For app-only iteration, use make push-app.
For GPT / U-Boot / MiniLoader storage / factory reset, use make flash.
SSH upgrade needs archive + .sig (OTA_SIGNING_KEY / make sign-keys); RockUSB di does not.

Env (also in repo-root \`.env\`; command-line env overrides \`.env\`):
  APP                       Flutter product under app/ (default: lws_hmi)
  SN / IP                   select board
  UPGRADE_TRANSPORT         auto|ssh|rockusb (default: auto)
  UPGRADE_PACKAGE           existing .tar/.tar.gz/.tgz; skips pack-ota rebuild.
                            SSH: also needs sibling <path>.sig (host HTTP + device pull).
                            RockUSB: host extracts then di (no .sig required).
                            Members: boot.img + boot_b.img + rootfs.img [/oem.img];
                            OEM_ONLY=1 requires oem.img (no auto-detect from archive).
  OTA_SIGNING_KEY           Ed25519 PEM (default keys/ota/ed25519.pem if present)
  OTA_HTTP_HOST             bind/advertise IP for host HTTP (USB-SSH default 192.168.55.2)
  OTA_HTTP_PORT             host HTTP port (default 0 = ephemeral)
  FIRMWARE_DIR      default: output/firmware
  FACTORY_SKU / OEM_ID      resolve default oem.img
  OEM_IMG                   oem.img path; unset=auto; empty=skip oem
  OEM_ONLY                  0|1 — 1 = oem partition only (required for oem-only packages)

Examples:
  APP=cnc_hmi make upgrade
  OEM_ONLY=1 make upgrade
  OEM_IMG= make upgrade
  UPGRADE_PACKAGE=/path/to/ota-package.tar.gz make upgrade
  UPGRADE_TRANSPORT=rockusb UPGRADE_PACKAGE=/path/to/ota-package.tar.gz make upgrade
  UPGRADE_TRANSPORT=rockusb make upgrade
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

board_preflight() {
	remote "$PREFLIGHT_REMOTE"
}

file_size() {
	local path="$1"
	if stat -f%z "$path" >/dev/null 2>&1; then
		stat -f%z "$path"
	else
		stat -c%s "$path"
	fi
}

parse_preflight() {
	local line key val
	ACTIVE=""
	INACTIVE=""
	ROOT_DEV=""
	ROOT_CAP=""
	BOOT_DEV=""
	BOOT_CAP=""
	OEM_DEV=""
	OEM_CAP=""
	FIT_NAME=""
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%$'\r'}"
		[[ "$line" == *=* ]] || continue
		key="${line%%=*}"
		val="${line#*=}"
		case "$key" in
		active) ACTIVE="$val" ;;
		inactive) INACTIVE="$val" ;;
		root_dev) ROOT_DEV="$val" ;;
		root_cap) ROOT_CAP="$val" ;;
		boot_dev) BOOT_DEV="$val" ;;
		boot_cap) BOOT_CAP="$val" ;;
		oem_dev) OEM_DEV="$val" ;;
		oem_cap) OEM_CAP="$val" ;;
		fit_name) FIT_NAME="$val" ;;
		esac
	done
}

resolve_bundle_images() {
	BOOT_IMG="$FIRMWARE/boot.img"
	BOOT_B_IMG="$FIRMWARE/boot_b.img"
	ROOTFS_IMG=""

	if [[ "$OEM_ONLY" == "1" ]]; then
		[[ -n "$OEM_IMG" ]] || die "OEM_ONLY=1 requires oem.img — run: make build-oem (or set OEM_IMG=)"
		[[ -f "$OEM_IMG" ]] || die "OEM_IMG not found: $OEM_IMG"
		return 0
	fi

	if [[ -n "$OEM_IMG" ]]; then
		[[ -f "$OEM_IMG" ]] || die "OEM_IMG not found: $OEM_IMG"
	else
		echo "WARNING: oem.img not found at $FACTORY_OEM_IMG — upgrading boot/rootfs only (run make build-oem)" >&2
	fi

	[[ -f "$BOOT_IMG" ]] || die "missing $BOOT_IMG — run: make build-kernel"
	[[ -f "$BOOT_B_IMG" ]] || die "missing $BOOT_B_IMG — run: make build-kernel"
	for candidate in "$APP_ROOTFS_IMG" "$FIRMWARE/rootfs.img" \
		"$APP_FIRMWARE_DIR/rootfs.ext2" "$FIRMWARE/rootfs.ext2"; do
		if [[ -f "$candidate" ]]; then
			ROOTFS_IMG="$candidate"
			break
		fi
	done
	[[ -n "$ROOTFS_IMG" ]] || die "missing $APP_ROOTFS_IMG — run: APP=$APP make build-rootfs"
	echo "upgrade: APP=$APP rootfs=$ROOTFS_IMG"
}

# Normalize UPGRADE_PACKAGE to an absolute readable regular file; reject non-tar suffixes.
validate_upgrade_package_path() {
	local pkg="${UPGRADE_PACKAGE:-}"
	[[ -n "$pkg" ]] || return 0
	# Relative paths are resolved from the caller's cwd (Make runs from repo root).
	if [[ "$pkg" != /* ]]; then
		pkg="$(pwd)/$pkg"
	fi
	[[ -e "$pkg" ]] || die "UPGRADE_PACKAGE not found: $pkg"
	[[ -f "$pkg" ]] || die "UPGRADE_PACKAGE must be a regular file (got: $pkg)"
	[[ -r "$pkg" ]] || die "UPGRADE_PACKAGE not readable: $pkg"
	case "$pkg" in
	*.tar.gz | *.tgz | *.tar) ;;
	*) die "UPGRADE_PACKAGE must be .tar / .tar.gz / .tgz (got: $pkg)" ;;
	esac
	[[ "$(file_size "$pkg")" -gt 0 ]] || die "UPGRADE_PACKAGE is empty: $pkg"
	UPGRADE_PACKAGE="$pkg"
	echo "upgrade: using UPGRADE_PACKAGE=$UPGRADE_PACKAGE"
}

# List basename of each archive member (handles ./boot.img → boot.img).
list_upgrade_package_basenames() {
	local pkg="$1"
	local line base
	local -a raw=()
	case "$pkg" in
	*.tar.gz | *.tgz)
		while IFS= read -r line; do
			[[ -n "$line" ]] && raw+=("$line")
		done < <(tar -tzf "$pkg" 2>/dev/null) \
			|| die "failed to list UPGRADE_PACKAGE (gzip tar): $pkg"
		;;
	*.tar)
		while IFS= read -r line; do
			[[ -n "$line" ]] && raw+=("$line")
		done < <(tar -tf "$pkg" 2>/dev/null) \
			|| die "failed to list UPGRADE_PACKAGE (tar): $pkg"
		;;
	*) die "UPGRADE_PACKAGE must be .tar / .tar.gz / .tgz (got: $pkg)" ;;
	esac
	[[ ${#raw[@]} -gt 0 ]] || die "UPGRADE_PACKAGE has no members: $pkg"
	for line in "${raw[@]}"; do
		base="${line%/}"
		base="${base##*/}"
		[[ -n "$base" ]] || continue
		printf '%s\n' "$base"
	done
}

archive_has_member() {
	local needle="$1"
	local m
	for m in "${UPGRADE_PACKAGE_MEMBERS[@]:-}"; do
		[[ "$m" == "$needle" ]] && return 0
	done
	return 1
}

	# Fail fast if required members for OEM_ONLY / transport are missing (before transfer/di).
verify_upgrade_package_members() {
	local transport="$1"
	local missing=()
	local m line
	UPGRADE_PACKAGE_MEMBERS=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && UPGRADE_PACKAGE_MEMBERS+=("$line")
	done < <(list_upgrade_package_basenames "$UPGRADE_PACKAGE" | sort -u)
	echo "upgrade: archive members: ${UPGRADE_PACKAGE_MEMBERS[*]}"

	if [[ "$OEM_ONLY" == "1" ]]; then
		archive_has_member oem.img || missing+=(oem.img)
	else
		for m in boot.img boot_b.img rootfs.img; do
			archive_has_member "$m" || missing+=("$m")
		done
	fi
	if [[ ${#missing[@]} -gt 0 ]]; then
		die "UPGRADE_PACKAGE missing required member(s) for ${transport} OEM_ONLY=${OEM_ONLY}: ${missing[*]} (set OEM_ONLY=1 for oem-only archives)"
	fi
}

cleanup_upgrade_package_extract() {
	if [[ -n "${UPGRADE_PACKAGE_EXTRACT_DIR:-}" && -d "${UPGRADE_PACKAGE_EXTRACT_DIR:-}" ]]; then
		rm -rf "$UPGRADE_PACKAGE_EXTRACT_DIR"
		UPGRADE_PACKAGE_EXTRACT_DIR=""
	fi
}

# Extract OTA images for RockUSB upgrade-ota / di. No .sig required.
extract_upgrade_package_rockusb() {
	local pkg="$UPGRADE_PACKAGE"
	local -a want=()
	local name

	UPGRADE_PACKAGE_EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-upgrade-pkg.XXXXXX")"
	trap 'cleanup_upgrade_package_extract' EXIT

	if [[ "$OEM_ONLY" == "1" ]]; then
		want=(oem.img)
	else
		want=(boot.img boot_b.img rootfs.img)
		archive_has_member oem.img && want+=(oem.img)
	fi

	echo "upgrade: extracting ${want[*]} from $pkg → $UPGRADE_PACKAGE_EXTRACT_DIR"
	case "$pkg" in
	*.tar.gz | *.tgz)
		tar -xzf "$pkg" -C "$UPGRADE_PACKAGE_EXTRACT_DIR" "${want[@]}" \
			|| die "failed to extract required members from $pkg"
		;;
	*.tar)
		tar -xf "$pkg" -C "$UPGRADE_PACKAGE_EXTRACT_DIR" "${want[@]}" \
			|| die "failed to extract required members from $pkg"
		;;
	esac

	# Flatten if archive used a leading ./ or nested path (basename already verified).
	for name in "${want[@]}"; do
		if [[ ! -f "$UPGRADE_PACKAGE_EXTRACT_DIR/$name" ]]; then
			local found
			found="$(find "$UPGRADE_PACKAGE_EXTRACT_DIR" -type f -name "$name" 2>/dev/null | head -n1 || true)"
			[[ -n "$found" ]] || die "extract missing $name after untar: $pkg"
			mv -f "$found" "$UPGRADE_PACKAGE_EXTRACT_DIR/$name"
		fi
		[[ -f "$UPGRADE_PACKAGE_EXTRACT_DIR/$name" ]] || die "extract missing $name: $pkg"
	done

	if [[ "$OEM_ONLY" == "1" ]]; then
		OEM_IMG="$UPGRADE_PACKAGE_EXTRACT_DIR/oem.img"
		BOOT_IMG=""
		BOOT_B_IMG=""
		ROOTFS_IMG=""
	else
		BOOT_IMG="$UPGRADE_PACKAGE_EXTRACT_DIR/boot.img"
		BOOT_B_IMG="$UPGRADE_PACKAGE_EXTRACT_DIR/boot_b.img"
		ROOTFS_IMG="$UPGRADE_PACKAGE_EXTRACT_DIR/rootfs.img"
		if [[ -f "$UPGRADE_PACKAGE_EXTRACT_DIR/oem.img" ]]; then
			OEM_IMG="$UPGRADE_PACKAGE_EXTRACT_DIR/oem.img"
		else
			OEM_IMG=""
			echo "WARNING: UPGRADE_PACKAGE has no oem.img — RockUSB will di boot/rootfs only" >&2
		fi
	fi
	echo "upgrade: RockUSB images from package (APP=$APP)"
}

ensure_ota_package() {
	local pkg="${UPGRADE_PACKAGE:-}"
	local sig=""
	if [[ -n "$pkg" ]]; then
		# Path/format already validated; SSH requires sibling .sig.
		OTA_ARCHIVE="$pkg"
		sig="${pkg}.sig"
		[[ -f "$sig" ]] || die "missing sibling signature $sig (required for SSH make upgrade)"
		[[ -r "$sig" ]] || die "sibling signature not readable: $sig"
		OTA_SIG="$sig"
		echo "upgrade: SSH serving UPGRADE_PACKAGE=$OTA_ARCHIVE (+ $OTA_SIG)"
		return 0
	fi

	echo "upgrade: running pack-ota (archive + .sig for SSH staged verify)..."
	APP="$APP" OEM_ONLY="$OEM_ONLY" \
		OEM_IMG="${OEM_IMG-}" \
		FIRMWARE_DIR="$FIRMWARE" \
		REQUIRE_OTA_SIG=1 \
		bash "$ROOT/scripts/pack-ota.sh" \
		|| die "pack-ota failed — set OTA_SIGNING_KEY= or run: make sign-keys"
	OTA_ARCHIVE="$APP_FIRMWARE_DIR/ota-package.tar.gz"
	OTA_SIG="${OTA_ARCHIVE}.sig"
	[[ -f "$OTA_ARCHIVE" ]] || die "missing OTA archive after pack-ota: $OTA_ARCHIVE"
	[[ -f "$OTA_SIG" ]] || die "missing OTA signature after pack-ota: $OTA_SIG"
	echo "upgrade: archive=$OTA_ARCHIVE ($(file_size "$OTA_ARCHIVE") bytes)"
	echo "upgrade: signature=$OTA_SIG ($(file_size "$OTA_SIG") bytes)"
}

# Returns 0 if a deployable Linux SSH target matches current SN=/IP=/IFACE=.
probe_ssh_target() {
	local errfile out
	errfile="$(mktemp "${TMPDIR:-/tmp}/lws-upgrade-ssh-probe.XXXXXX")"
	if out=$(
		SN="${SN:-}" CHIP_ID="${CHIP_ID:-}" SERIAL="${SERIAL:-}" IP="${IP:-}" IFACE="${IFACE:-}" \
			bash "$ROOT/scripts/device-target.sh" --select 2>"$errfile"
	); then
		rm -f "$errfile"
		local -a sel=()
		local line
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
		*) return 1 ;;
		esac
		return 0
	fi
	if grep -qE 'devices — set SN|matches .* devices' "$errfile" 2>/dev/null; then
		cat "$errfile" >&2
		rm -f "$errfile"
		die "multiple SSH targets — set SN= or IP= (see make devices)"
	fi
	rm -f "$errfile"
	return 1
}

probe_rockusb_available() {
	local tool_dir tool out
	case "$(uname -s)" in
	Darwin)
		tool_dir="$ROOT/tools/upgrade_tool/macos"
		tool="$tool_dir/upgrade_tool"
		;;
	Linux)
		tool_dir="$ROOT/tools/upgrade_tool/linux"
		tool="$tool_dir/upgrade_tool"
		;;
	MINGW* | MSYS* | CYGWIN*)
		tool_dir="$ROOT/tools/upgrade_tool/windows"
		tool="$tool_dir/upgrade_tool.exe"
		;;
	*)
		return 1
		;;
	esac
	[[ -f "$tool" ]] || return 1
	[[ -x "$tool" ]] || chmod +x "$tool" 2>/dev/null || true
	[[ -x "$tool" ]] || return 1
	out="$(cd "$tool_dir" && "$tool" ld 2>&1 | grep -v '^Using ' || true)"
	[[ "$out" =~ connected\(([1-9][0-9]*)\) ]]
}

decide_transport() {
	local want="${UPGRADE_TRANSPORT:-auto}"
	case "$want" in
	auto | "")
		if [[ -n "${IP:-}" || -n "${IFACE:-}" ]]; then
			probe_ssh_target || die "UPGRADE_TRANSPORT=auto with IP=/IFACE= but no SSH target (make devices / make connect)"
			CHOSEN_TRANSPORT=ssh
			return 0
		fi
		if probe_ssh_target; then
			CHOSEN_TRANSPORT=ssh
			return 0
		fi
		if probe_rockusb_available; then
			CHOSEN_TRANSPORT=rockusb
			return 0
		fi
		die "No upgrade target. Plug USB-SSH / make connect <ip>, or enter RockUSB Loader (make reboot-loader) / Maskrom. See: make devices"
		;;
	ssh)
		probe_ssh_target || die "UPGRADE_TRANSPORT=ssh but no SSH Linux target (make devices / make connect)"
		CHOSEN_TRANSPORT=ssh
		;;
	rockusb)
		probe_rockusb_available || die "UPGRADE_TRANSPORT=rockusb but no RockUSB Loader/Maskrom device (make reboot-loader or Maskrom; see make devices)"
		CHOSEN_TRANSPORT=rockusb
		;;
	*)
		die "UPGRADE_TRANSPORT must be auto|ssh|rockusb (got: $want)"
		;;
	esac
}

run_rockusb_upgrade() {
	echo "Bundle (host check):"
	if [[ "$OEM_ONLY" == "1" ]]; then
		ls -lh "$OEM_IMG"
	else
		ls -lh "$BOOT_IMG" "$BOOT_B_IMG" "$ROOTFS_IMG" ${OEM_IMG:+"$OEM_IMG"}
		local verify_dir="$FIRMWARE"
		if [[ -n "${UPGRADE_PACKAGE_EXTRACT_DIR:-}" && -d "${UPGRADE_PACKAGE_EXTRACT_DIR:-}" ]]; then
			verify_dir="$UPGRADE_PACKAGE_EXTRACT_DIR"
		fi
		bash "$ROOT/scripts/verify-firmware-partitions.sh" "$verify_dir" "$ROOT/board/parameter-buildroot-fit.txt" \
			"$ROOTFS_IMG" \
			|| die "bundle exceeds GPT slot sizes"
	fi

	if [[ -n "${IMAGE:-}" ]]; then
		echo "WARNING: IMAGE= is ignored on RockUSB make upgrade (use make flash for factory.img)" >&2
	fi

	export UPGRADE_OTA_BOOT_IMG="${BOOT_IMG:-}"
	export UPGRADE_OTA_BOOT_B_IMG="${BOOT_B_IMG:-}"
	export UPGRADE_OTA_ROOTFS_IMG="${ROOTFS_IMG:-}"
	export UPGRADE_OTA_OEM_IMG="${OEM_IMG:-}"
	export OEM_ONLY
	bash "$ROOT/scripts/flash-usb.sh" upgrade-ota
	cleanup_upgrade_package_extract
	trap - EXIT
}

wait_ota_http_transfer_complete() {
	# Wait until ota-http-serve.py prints TRANSFER_COMPLETE (archive + .sig fully GET).
	local timeout="${1:-600}"
	local i
	for ((i = 0; i < timeout * 10; i++)); do
		if ! kill -0 "${OTA_HTTP_PID:-0}" 2>/dev/null; then
			die "ota-http-serve exited before TRANSFER_COMPLETE (device may not have fetched the package)"
		fi
		if grep -qx 'TRANSFER_COMPLETE' "${OTA_HTTP_LOG:-/dev/null}" 2>/dev/null; then
			return 0
		fi
		sleep 0.1
	done
	die "timed out waiting for host HTTP TRANSFER_COMPLETE (${timeout}s) — is the board downloading from $OTA_HTTP_BASE?"
}

# Resolve IPv4 the device uses to reach this host's ephemeral OTA HTTP server.
resolve_ota_http_bind() {
	if [[ -n "${OTA_HTTP_HOST:-}" ]]; then
		OTA_HTTP_BIND="$OTA_HTTP_HOST"
		return 0
	fi
	case "${TRANSPORT:-}" in
	usb-ssh)
		OTA_HTTP_BIND="${USB_HOST_ADDR:-${USB_SSH_HOST_ADDR:-192.168.55.2}}"
		return 0
		;;
	esac
	# LAN SSH: UDP connect trick → local source address toward the board.
	OTA_HTTP_BIND="$(
		python3 - "$TARGET_ADDR" <<'PY'
import socket
import sys

target = sys.argv[1].split("%", 1)[0]
host = target
port = 22
if host.startswith("[") and "]" in host:
    # rare IPv6 literal — skip
    print("")
    raise SystemExit(0)
if ":" in host and host.count(":") == 1:
    h, p = host.rsplit(":", 1)
    if p.isdigit():
        host, port = h, int(p)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    sock.connect((host, port))
    print(sock.getsockname()[0])
except OSError:
    print("")
finally:
    sock.close()
PY
	)"
	[[ -n "$OTA_HTTP_BIND" ]] || die "cannot resolve OTA_HTTP_HOST for LAN target $TARGET_ADDR (set OTA_HTTP_HOST=)"
}

start_ota_http_server() {
	# Sets OTA_HTTP_PID, OTA_HTTP_BASE, OTA_HTTP_SERVE_DIR
	# stdout → log (base URL); stderr → caller terminal (chunk send progress)
	local archive="$1" sig="$2"
	local port="${OTA_HTTP_PORT:-0}"
	local log
	OTA_HTTP_SERVE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-ota-http.XXXXXX")"
	ln "$archive" "$OTA_HTTP_SERVE_DIR/ota-package.tar.gz" 2>/dev/null \
		|| cp -f "$archive" "$OTA_HTTP_SERVE_DIR/ota-package.tar.gz"
	ln "$sig" "$OTA_HTTP_SERVE_DIR/ota-package.tar.gz.sig" 2>/dev/null \
		|| cp -f "$sig" "$OTA_HTTP_SERVE_DIR/ota-package.tar.gz.sig"
	log="$(mktemp "${TMPDIR:-/tmp}/lws-ota-http-log.XXXXXX")"
	python3 "$ROOT/scripts/ota-http-serve.py" \
		--bind "$OTA_HTTP_BIND" \
		--port "$port" \
		--dir "$OTA_HTTP_SERVE_DIR" \
		>"$log" &
	OTA_HTTP_PID=$!
	OTA_HTTP_LOG="$log"
	local i line
	for ((i = 0; i < 50; i++)); do
		if ! kill -0 "$OTA_HTTP_PID" 2>/dev/null; then
			cat "$log" >&2 || true
			die "ota-http-serve exited early (bind $OTA_HTTP_BIND:$port)"
		fi
		line="$(head -n1 "$log" 2>/dev/null || true)"
		if [[ "$line" == http://* ]]; then
			OTA_HTTP_BASE="${line%/}/"
			return 0
		fi
		sleep 0.1
	done
	kill "$OTA_HTTP_PID" 2>/dev/null || true
	cat "$log" >&2 || true
	die "ota-http-serve did not print base URL"
}

stop_ota_http_server() {
	if [[ -n "${OTA_HTTP_PID:-}" ]]; then
		kill "$OTA_HTTP_PID" 2>/dev/null || true
		wait "$OTA_HTTP_PID" 2>/dev/null || true
		OTA_HTTP_PID=""
	fi
	if [[ -n "${OTA_HTTP_SERVE_DIR:-}" && -d "${OTA_HTTP_SERVE_DIR:-}" ]]; then
		rm -rf "$OTA_HTTP_SERVE_DIR"
		OTA_HTTP_SERVE_DIR=""
	fi
	if [[ -n "${OTA_HTTP_LOG:-}" ]]; then
		rm -f "$OTA_HTTP_LOG"
		OTA_HTTP_LOG=""
	fi
}

run_ssh_upgrade() {
	local MODE_LABEL OEM_FLAG PACKAGE_URL
	local OTA_HTTP_PID="" OTA_HTTP_BASE="" OTA_HTTP_SERVE_DIR="" OTA_HTTP_LOG="" OTA_HTTP_BIND=""

	if is_android_emulator_serial "$(device_select_sn)"; then
		die "Android emulator ($(device_select_sn)) is not supported for upgrade (physical board only; see make devices)"
	fi
	if is_emulator_ssh_endpoint "${TARGET_ADDR:-}"; then
		die "QEMU emulator ($TARGET_ADDR) is not supported for upgrade (use make build-emulator + make emulator)"
	fi

	if [[ "$OEM_ONLY" == "1" ]]; then
		MODE_LABEL="OEM-only"
		OEM_FLAG="oem_only=1"
	else
		MODE_LABEL="full-system A/B"
		OEM_FLAG="oem_only=0"
	fi
	if usb_ssh_session_is_remote; then
		echo "SSH $MODE_LABEL upgrade (host HTTP + device pull): target=$TARGET_USER@$TARGET_ADDR"
	else
		echo "USB-SSH $MODE_LABEL upgrade (host HTTP + device pull): iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
	fi
	usb_ssh_session_configure_link
	usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "${WAIT_SEC:-30}"
	TARGET_SERIAL_HINT=""
	if ! usb_ssh_session_is_remote; then
		TARGET_SERIAL_HINT="$(
			bash "$ROOT/scripts/usb-ssh-devices.sh" --tsv 2>/dev/null |
				awk -F'\t' -v iface="$IFACE" \
					'$1 == "USB-SSH" && $4 == iface {print $2; exit}' ||
				true
		)"
	fi

	trap 'stop_ota_http_server' EXIT

	ensure_ota_package
	[[ -n "${OTA_SIG:-}" && -f "$OTA_SIG" ]] || die "missing OTA_SIG for SSH upgrade"
	[[ "$(file_size "$OTA_ARCHIVE")" -gt 0 ]] || die "OTA archive is empty: $OTA_ARCHIVE"

	echo "Bundle (host check):"
	ls -lh "$OTA_ARCHIVE" "$OTA_SIG"
	# Tree GPT size check only when packaging from loose imgs (not UPGRADE_PACKAGE).
	if [[ -z "${UPGRADE_PACKAGE:-}" && "$OEM_ONLY" != "1" ]]; then
		bash "$ROOT/scripts/verify-firmware-partitions.sh" "$FIRMWARE" "$ROOT/board/parameter-buildroot-fit.txt" \
			"$ROOTFS_IMG" \
			|| die "bundle exceeds GPT slot sizes"
	fi

	remote "mkdir -p $OTA_DIR /run/hmi && rm -f $OTA_DIR/apply.status $OTA_DIR/progress.json $OTA_DIR/ota.log $ARCHIVE_REMOTE ${ARCHIVE_REMOTE}.sig $OTA_DIR/boot.img $OTA_DIR/boot_b.img $OTA_DIR/rootfs.img $OTA_DIR/oem.img $OTA_DIR/manifest.json $OTA_DIR/*.sha256 $OTA_DIR/ab-upgrade-stream.sh $OTA_DIR/ab-slot-lib.sh $OTA_DIR/ab-upgrade-apply.sh $OTA_DIR/ab-ota-verify.sh"

	if ! usb_ssh_session_is_remote; then
		remote "/usr/bin/systemctl.real stop wlan-wpa.service >/dev/null 2>&1 || true"
	fi

	echo "Preflight slot state..."
	set +e
	PREFLIGHT_RAW="$(board_preflight 2>&1)"
	preflight_rc=$?
	set -e
	[[ "$preflight_rc" -eq 0 ]] || {
		printf '%s\n' "$PREFLIGHT_RAW" >&2
		die "board preflight failed (unsafe slot state or missing $PREFLIGHT_REMOTE — rebuild rootfs)"
	}
	parse_preflight <<<"$PREFLIGHT_RAW"

	if [[ "$OEM_ONLY" == "1" ]]; then
		[[ -n "$OEM_DEV" ]] || die "OEM_ONLY=1 but board has no oem partition. Got:
$PREFLIGHT_RAW"
		# Host size check needs a local oem.img; skip when serving a prebuilt package.
		if [[ -z "${UPGRADE_PACKAGE:-}" ]]; then
			OEM_BYTES="$(file_size "$OEM_IMG")"
			[[ "$OEM_BYTES" -le "${OEM_CAP:-0}" ]] || die "oem.img ($OEM_BYTES) > oem cap ($OEM_CAP)"
		fi
	else
		[[ -n "$INACTIVE" && -n "$ROOT_DEV" && -n "$BOOT_DEV" && -n "$FIT_NAME" ]] \
			|| die "preflight missing fields (inactive/root_dev/boot_dev/fit_name). Got:
$PREFLIGHT_RAW"
	fi

	resolve_ota_http_bind
	echo "Serving OTA package on $OTA_HTTP_BIND (device will HTTP GET)..."
	start_ota_http_server "$OTA_ARCHIVE" "$OTA_SIG"
	PACKAGE_URL="${OTA_HTTP_BASE}ota-package.tar.gz"
	echo "  package_url=$PACKAGE_URL"

	echo "Triggering HMI download ($OEM_FLAG)..."
	remote "printf 'download %s %s\\n' '$PACKAGE_URL' '$OEM_FLAG' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

	echo "Waiting for device to HTTP GET archive + .sig (host send progress on stderr)..."
	wait_ota_http_transfer_complete 600

	stop_ota_http_server
	trap - EXIT

	bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
		"$TRANSPORT" "$IFACE" "$TARGET_ADDR" "$TARGET_SERIAL_HINT" || true
	echo "Transfer complete. Device will verify/apply and reboot on its own — watch the HMI upgrade page."
	exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

case "$OEM_ONLY" in
0 | 1) ;;
*) die "OEM_ONLY must be 0 or 1 (got: $OEM_ONLY)" ;;
esac

_CLI_UPGRADE_TRANSPORT="${UPGRADE_TRANSPORT-}"
_CLI_UPGRADE_TRANSPORT_SET=0
[[ -n "${UPGRADE_TRANSPORT+x}" ]] && _CLI_UPGRADE_TRANSPORT_SET=1
_CLI_UPGRADE_PACKAGE="${UPGRADE_PACKAGE-}"
_CLI_UPGRADE_PACKAGE_SET=0
[[ -n "${UPGRADE_PACKAGE+x}" ]] && _CLI_UPGRADE_PACKAGE_SET=1

usb_ssh_session_load_env "$ROOT"

if [[ "$_CLI_UPGRADE_TRANSPORT_SET" == 1 ]]; then
	UPGRADE_TRANSPORT="$_CLI_UPGRADE_TRANSPORT"
fi
UPGRADE_TRANSPORT="${UPGRADE_TRANSPORT:-auto}"
if [[ "$_CLI_UPGRADE_PACKAGE_SET" == 1 ]]; then
	UPGRADE_PACKAGE="$_CLI_UPGRADE_PACKAGE"
fi

UPGRADE_PACKAGE_EXTRACT_DIR=""
UPGRADE_PACKAGE_MEMBERS=()

if [[ -n "${UPGRADE_PACKAGE:-}" ]]; then
	validate_upgrade_package_path
	# Member checks do not depend on transport (same dual-FIT / oem-only rules).
	verify_upgrade_package_members "${UPGRADE_TRANSPORT:-auto}"
else
	# Fail fast on missing tree images before device transport selection.
	resolve_bundle_images
fi

decide_transport

if [[ -n "${UPGRADE_PACKAGE:-}" && "$CHOSEN_TRANSPORT" == rockusb ]]; then
	extract_upgrade_package_rockusb
fi

case "$CHOSEN_TRANSPORT" in
ssh)
	run_ssh_upgrade
	;;
rockusb)
	run_rockusb_upgrade
	;;
*)
	die "internal: unknown transport $CHOSEN_TRANSPORT"
	;;
esac
