#!/usr/bin/env bash
# Remote firmware upgrade (make upgrade).
# Transports:
#   SSH (USB-SSH / LAN) — stream inactive rootfs + try-boot FIT (+ optional oem), then arm-reboot
#   RockUSB Loader/Maskrom — upgrade_tool di of OTA-equivalent loose images (not uf factory.img)
# OEM_ONLY=1: oem partition only (SSH plain-reboot; RockUSB di oem only).
# MUST NOT stage full firmware images under /userdata/ota/ (status/helpers only).
# Online OTA uses board ab-upgrade-apply.sh (download/stage then dd) — not this path.
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

FIRMWARE="${LWS_HMI_FIRMWARE_DIR:-$ROOT/output/firmware}"
OTA_DIR="/userdata/ota"
HELPER_SRC_DIR="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/ab"
STREAM_SRC="$HELPER_SRC_DIR/ab-upgrade-stream.sh"
LIB_SRC="$HELPER_SRC_DIR/ab-slot-lib.sh"
STREAM="$OTA_DIR/ab-upgrade-stream.sh"
STREAM_LIB="$OTA_DIR/ab-slot-lib.sh"
OEM_ONLY="${OEM_ONLY:-0}"
# UPGRADE_TRANSPORT defaulted after .env load (see main); optional: auto|ssh|rockusb

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

Firmware upgrade over SSH stream or RockUSB Loader/Maskrom (same make upgrade).

SSH (default when a Linux USB-SSH / registered SSH target is selected):
  Streams rootfs.img and the inactive letter's FIT into partitions, optionally
  streams oem.img, arms try-boot, and returns as soon as reboot is requested.

RockUSB (when Loader/Maskrom is selected, or UPGRADE_TRANSPORT=rockusb):
  upgrade_tool di of OTA-equivalent images: boot + boot_b + rootfs_a + rootfs_b
  (+ optional oem). Maskrom: ul MiniLoader into RAM first. Does NOT uf factory.img
  and does NOT rewrite uboot / GPT / misc. Not product OTA (no zip/sign/stage).

OEM_ONLY=1:
  oem partition only (SSH: plain reboot; RockUSB: di oem only).

Does not stage full images under /userdata/ota/ (unlike online OTA).
For app-only iteration, use make push-app.
For GPT / U-Boot / MiniLoader storage / factory reset, use make flash.

Env (also in repo-root \`.env\`; command-line env overrides \`.env\`):
  APP                       Flutter product under app/ (default: lws_hmi);
                            rootfs from output/firmware/<APP>/rootfs.img
  SN                        select board when multiple devices
  IP                        registered SSH only (make connect <ip>)
  UPGRADE_TRANSPORT         auto|ssh|rockusb (default: auto)
  LWS_HMI_FIRMWARE_DIR      default: output/firmware (shared boot FITs)
  FACTORY_SKU / OEM_ID      resolve default oem.img (see board/factory-skus.tsv)
  OEM_IMG                   oem.img path; unset=auto from FACTORY_SKU; empty=skip oem
  OEM_ONLY                  0|1 — 1 = oem partition only (requires oem.img)

Examples:
  APP=cnc_hmi make upgrade
  OEM_ONLY=1 make upgrade
  OEM_IMG= make upgrade          # full upgrade without oem
  UPGRADE_TRANSPORT=rockusb make upgrade
  make reboot-loader && make upgrade
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

stream_sh() {
	remote "env LWS_HMI_AB_LIB=$STREAM_LIB /bin/sh $STREAM $*"
}

file_size() {
	local path="$1"
	if stat -f%z "$path" >/dev/null 2>&1; then
		stat -f%z "$path"
	else
		stat -c%s "$path"
	fi
}

stream_to_dev() {
	local src="$1"
	local dest_dev="$2"
	local label="$3"
	local offset="$4"
	local total="$5"
	local bytes
	bytes="$(file_size "$src")"
	python3 "$ROOT/scripts/stream-file-progress.py" \
		--label "$label" --offset "$offset" --total "$total" "$src" |
		remote "env LWS_HMI_AB_LIB=$STREAM_LIB /bin/sh $STREAM write '$dest_dev' $bytes"
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

# Returns 0 if a deployable Linux SSH target matches current SN=/IP=/IFACE=.
# Prints nothing; on multi-match / hard select errors, exits via die when force_ssh=1
# or when the select error is "ambiguous" (operator must disambiguate).
probe_ssh_target() {
	local errfile out
	errfile="$(mktemp "${TMPDIR:-/tmp}/lws-upgrade-ssh-probe.XXXXXX")"
	if out=$(
		SN="${SN:-}" CHIP_ID="${CHIP_ID:-}" SERIAL="${SERIAL:-}" IP="${IP:-}" IFACE="${IFACE:-}" \
			bash "$ROOT/scripts/device-target.sh" --select 2>"$errfile"
	); then
		rm -f "$errfile"
		# Populate session vars like try_select
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
	# Ambiguous multi-device must not silently fall through to RockUSB.
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
		# IP=/IFACE= imply SSH-only selection.
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
		bash "$ROOT/scripts/verify-firmware-partitions.sh" "$FIRMWARE" "$ROOT/board/parameter-buildroot-fit.txt" \
			"$ROOTFS_IMG" \
			|| die "bundle exceeds GPT slot sizes"
	fi

	# Refuse factory / uf path variables being used as the payload.
	if [[ -n "${IMAGE:-}" ]]; then
		echo "WARNING: IMAGE= is ignored on RockUSB make upgrade (use make flash for factory.img)" >&2
	fi

	export UPGRADE_OTA_BOOT_IMG="${BOOT_IMG:-}"
	export UPGRADE_OTA_BOOT_B_IMG="${BOOT_B_IMG:-}"
	export UPGRADE_OTA_ROOTFS_IMG="${ROOTFS_IMG:-}"
	export UPGRADE_OTA_OEM_IMG="${OEM_IMG:-}"
	export OEM_ONLY
	# SN/ selection already in env for flash-usb.sh
	bash "$ROOT/scripts/flash-usb.sh" upgrade-ota
}

run_ssh_upgrade() {
	local MODE_LABEL

	if is_android_emulator_serial "$(device_select_sn)"; then
		die "Android emulator ($(device_select_sn)) is not supported for upgrade (physical board only; see make devices)"
	fi
	# TRANSPORT/IFACE/TARGET_ADDR already set by decide_transport → probe_ssh_target
	if is_emulator_ssh_endpoint "${TARGET_ADDR:-}"; then
		die "QEMU emulator ($TARGET_ADDR) is not supported for upgrade (use make build-emulator + make emulator)"
	fi

	if [[ "$OEM_ONLY" == "1" ]]; then
		MODE_LABEL="OEM-only"
	else
		MODE_LABEL="full-system A/B"
	fi
	if usb_ssh_session_is_remote; then
		echo "SSH $MODE_LABEL upgrade (stream-to-partition): target=$TARGET_USER@$TARGET_ADDR"
	else
		echo "USB-SSH $MODE_LABEL upgrade (stream-to-partition): iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
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

	echo "Bundle (host check):"
	if [[ "$OEM_ONLY" == "1" ]]; then
		ls -lh "$OEM_IMG"
	else
		ls -lh "$BOOT_IMG" "$BOOT_B_IMG" "$ROOTFS_IMG" ${OEM_IMG:+"$OEM_IMG"}
		bash "$ROOT/scripts/verify-firmware-partitions.sh" "$FIRMWARE" "$ROOT/board/parameter-buildroot-fit.txt" \
			"$ROOTFS_IMG" \
			|| die "bundle exceeds GPT slot sizes"
	fi

	[[ -r "$STREAM_SRC" && -r "$LIB_SRC" ]] || die "A/B stream helpers missing from repository overlay"

	remote "mkdir -p $OTA_DIR && rm -f $OTA_DIR/apply.status $OTA_DIR/boot.img $OTA_DIR/boot_b.img $OTA_DIR/rootfs.img $OTA_DIR/oem.img $OTA_DIR/manifest.json $OTA_DIR/*.sha256 $STREAM $STREAM_LIB"

	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"$STREAM_SRC" "$LIB_SRC" \
		"$TARGET_USER@$TARGET_ADDR:$OTA_DIR/"

	if ! usb_ssh_session_is_remote; then
		remote "/usr/bin/systemctl.real stop wlan-wpa.service >/dev/null 2>&1 || true"
	fi

	echo "Preflight slot state..."
	set +e
	PREFLIGHT_RAW="$(stream_sh preflight 2>&1)"
	preflight_rc=$?
	set -e
	[[ "$preflight_rc" -eq 0 ]] || {
		printf '%s\n' "$PREFLIGHT_RAW" >&2
		die "board preflight failed (unsafe slot state or missing helpers)"
	}
	parse_preflight <<<"$PREFLIGHT_RAW"

	if [[ "$OEM_ONLY" == "1" ]]; then
		[[ -n "$OEM_DEV" ]] || die "OEM_ONLY=1 but board has no oem partition. Got:
$PREFLIGHT_RAW"
		OEM_BYTES="$(file_size "$OEM_IMG")"
		[[ "$OEM_BYTES" -le "${OEM_CAP:-0}" ]] || die "oem.img ($OEM_BYTES) > oem cap ($OEM_CAP)"
		STREAM_TOTAL="$OEM_BYTES"

		echo "Stream apply (OEM only): oem → $OEM_DEV"
		stream_sh set-status running
		echo "Writing oem.img (stream-to-partition)..."
		stream_to_dev "$OEM_IMG" "$OEM_DEV" "oem.img" 0 "$STREAM_TOTAL" \
			|| die "oem stream failed"
		stream_sh set-status ok >/dev/null 2>&1 || true

		echo "Rebooting (plain; no A/B letter switch)..."
		# Same reboot path as full upgrade (systemctl.real --no-block via ab_reboot).
		# /sbin/reboot is unreliable here (wrapper / no-op under nohup).
		set +e
		arm_out="$(remote "nohup env LWS_HMI_AB_LIB=$STREAM_LIB /bin/sh $STREAM plain-reboot >/userdata/ota/apply.log 2>&1 </dev/null & echo REBOOT_STARTED")"
		arm_rc=$?
		set -e
		[[ "$arm_rc" -eq 0 && "$arm_out" == *REBOOT_STARTED* ]] || die "failed to start reboot"

		bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
			"$TRANSPORT" "$IFACE" "$TARGET_ADDR" "$TARGET_SERIAL_HINT" || true
		echo "OEM upgrade successfully, please wait for the device to restart."
		exit 0
	fi

	# --- full-system A/B path ---
	[[ -n "$INACTIVE" && -n "$ROOT_DEV" && -n "$BOOT_DEV" && -n "$FIT_NAME" ]] \
		|| die "preflight missing fields (inactive/root_dev/boot_dev/fit_name). Got:
$PREFLIGHT_RAW"

	case "$FIT_NAME" in
	boot.img) FIT_IMG="$BOOT_IMG" ;;
	boot_b.img) FIT_IMG="$BOOT_B_IMG" ;;
	*) die "unexpected fit_name=$FIT_NAME" ;;
	esac
	[[ -f "$FIT_IMG" ]] || die "missing inactive FIT $FIT_IMG"

	ROOT_BYTES="$(file_size "$ROOTFS_IMG")"
	FIT_BYTES="$(file_size "$FIT_IMG")"
	OEM_BYTES=0
	[[ "$ROOT_BYTES" -le "${ROOT_CAP:-0}" ]] || die "rootfs.img ($ROOT_BYTES) > inactive rootfs cap ($ROOT_CAP)"
	[[ "$FIT_BYTES" -le "${BOOT_CAP:-0}" ]] || die "$FIT_NAME ($FIT_BYTES) > boot cap ($BOOT_CAP)"

	STREAM_TOTAL=$((ROOT_BYTES + FIT_BYTES))
	if [[ -n "$OEM_IMG" ]]; then
		[[ -n "$OEM_DEV" ]] || die "OEM_IMG set but board has no oem partition"
		OEM_BYTES="$(file_size "$OEM_IMG")"
		[[ "$OEM_BYTES" -le "${OEM_CAP:-0}" ]] || die "oem.img ($OEM_BYTES) > oem cap ($OEM_CAP)"
		STREAM_TOTAL=$((STREAM_TOTAL + OEM_BYTES))
	fi

	echo "Stream apply: active=$ACTIVE inactive=$INACTIVE fit=$FIT_NAME"
	echo "  rootfs → $ROOT_DEV"
	echo "  $FIT_NAME → $BOOT_DEV (after boot→boot_b backup)"
	[[ -n "$OEM_IMG" ]] && echo "  oem → $OEM_DEV"

	stream_sh set-status running

	OVERALL_SENT=0
	echo "Writing firmware (stream-to-partition)..."
	stream_to_dev "$ROOTFS_IMG" "$ROOT_DEV" "rootfs.img" "$OVERALL_SENT" "$STREAM_TOTAL" \
		|| die "rootfs stream failed — try-boot not armed; active letter unchanged"
	OVERALL_SENT=$((OVERALL_SENT + ROOT_BYTES))

	stream_sh backup-boot \
		|| die "boot backup failed — try-boot not armed; active letter unchanged"

	stream_to_dev "$FIT_IMG" "$BOOT_DEV" "$FIT_NAME" "$OVERALL_SENT" "$STREAM_TOTAL" \
		|| die "FIT stream failed — try-boot not armed; active letter unchanged"
	OVERALL_SENT=$((OVERALL_SENT + FIT_BYTES))

	if [[ -n "$OEM_IMG" ]]; then
		stream_to_dev "$OEM_IMG" "$OEM_DEV" "oem.img" "$OVERALL_SENT" "$STREAM_TOTAL" \
			|| die "oem stream failed — try-boot not armed; active letter unchanged"
	fi

	echo "Arming try-boot and rebooting..."
	set +e
	arm_out="$(remote "nohup env LWS_HMI_AB_LIB=$STREAM_LIB /bin/sh $STREAM arm-reboot $INACTIVE >/userdata/ota/apply.log 2>&1 </dev/null & echo ARM_STARTED")"
	arm_rc=$?
	set -e
	[[ "$arm_rc" -eq 0 && "$arm_out" == *ARM_STARTED* ]] || die "failed to start arm-reboot"

	bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
		"$TRANSPORT" "$IFACE" "$TARGET_ADDR" "$TARGET_SERIAL_HINT" || true
	echo "Upgrade successfully, please wait for the device to restart."
	exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

case "$OEM_ONLY" in
0 | 1) ;;
*) die "OEM_ONLY must be 0 or 1 (got: $OEM_ONLY)" ;;
esac

# Preserve CLI/Make UPGRADE_TRANSPORT across usb_ssh_session_load_env (.env re-source).
_CLI_UPGRADE_TRANSPORT="${UPGRADE_TRANSPORT-}"
_CLI_UPGRADE_TRANSPORT_SET=0
[[ -n "${UPGRADE_TRANSPORT+x}" ]] && _CLI_UPGRADE_TRANSPORT_SET=1

usb_ssh_session_load_env "$ROOT"

if [[ "$_CLI_UPGRADE_TRANSPORT_SET" == 1 ]]; then
	UPGRADE_TRANSPORT="$_CLI_UPGRADE_TRANSPORT"
fi
UPGRADE_TRANSPORT="${UPGRADE_TRANSPORT:-auto}"

# Fail fast on missing images before device transport selection.
resolve_bundle_images

decide_transport

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
