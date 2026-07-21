#!/usr/bin/env bash
# Remote full-system firmware upgrade over USB-SSH / LAN SSH (make upgrade).
# Stream-to-partition: SSH stdin → inactive rootfs + try-boot FIT (optional oem).
# MUST NOT stage full firmware images under /userdata/ota/ (status/helpers only).
# Online OTA uses board ab-upgrade-apply.sh (download/stage then dd) — not this path.
# MUST NOT call RockUSB / upgrade_tool uf / flash-usb.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

FIRMWARE="${LWS_HMI_FIRMWARE_DIR:-$ROOT/output/firmware}"
OTA_DIR="/userdata/ota"
HELPER_SRC_DIR="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi"
STREAM_SRC="$HELPER_SRC_DIR/ab-upgrade-stream.sh"
LIB_SRC="$HELPER_SRC_DIR/ab-slot-lib.sh"
STREAM="$OTA_DIR/ab-upgrade-stream.sh"
STREAM_LIB="$OTA_DIR/ab-slot-lib.sh"
WAIT_REBOOT_SEC="${UPGRADE_WAIT_REBOOT_SEC:-300}"
OEM_IMG="${UPGRADE_OEM_IMG:-}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Remote A/B firmware upgrade over SSH (same target selection as make push-app).

Streams rootfs.img and the inactive letter's FIT (boot.img or boot_b.img)
directly into partitions with progress, arms try-boot, and reboots.
Does not stage full images under /userdata/ota/ (unlike online OTA).

For app-only iteration, use make push-app.
For online OTA staging semantics, use board ab-upgrade-apply.sh.

Env:
  SN / LWS_HMI_SN   select board when multiple devices
  IP / LWS_HMI_IP           registered SSH only (make connect <ip>)
  LWS_HMI_FIRMWARE_DIR      default: output/firmware
  UPGRADE_OEM_IMG           optional path to oem.img
  UPGRADE_WAIT_REBOOT_SEC   wait for reboot/SSH disconnect (default 300)

Does NOT enter RockUSB or run upgrade_tool uf. Use make flash for GPT/U-Boot.
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

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

# Guard: never invoke flash path
case "$*" in
*flash-usb*|*upgrade_tool*|*[[:space:]]uf[[:space:]]*) die "upgrade must not use RockUSB uf" ;;
esac

usb_ssh_session_load_env "$ROOT"
if is_android_emulator_serial "$(device_select_sn)"; then
	die "Android emulator ($(device_select_sn)) is not supported for upgrade (physical board only; see make devices)"
fi
usb_ssh_session_select "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH full-system upgrade (stream-to-partition): target=$TARGET_USER@$TARGET_ADDR"
else
	echo "USB-SSH full-system upgrade (stream-to-partition): iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
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

BOOT_IMG="$FIRMWARE/boot.img"
BOOT_B_IMG="$FIRMWARE/boot_b.img"
ROOTFS_IMG="$FIRMWARE/rootfs.img"
[[ -f "$BOOT_IMG" ]] || die "missing $BOOT_IMG — run: make build-kernel"
[[ -f "$BOOT_B_IMG" ]] || die "missing $BOOT_B_IMG — run: make build-kernel"
[[ -f "$ROOTFS_IMG" ]] || {
	if [[ -f "$ROOT/output/firmware/rootfs.ext2" ]]; then
		ROOTFS_IMG="$ROOT/output/firmware/rootfs.ext2"
	else
		die "missing $FIRMWARE/rootfs.img — run: make build-rootfs"
	fi
}
if [[ -n "$OEM_IMG" ]]; then
	[[ -f "$OEM_IMG" ]] || die "UPGRADE_OEM_IMG not found: $OEM_IMG"
fi

echo "Bundle (host check):"
ls -lh "$BOOT_IMG" "$BOOT_B_IMG" "$ROOTFS_IMG" ${OEM_IMG:+"$OEM_IMG"}
bash "$ROOT/scripts/verify-firmware-partitions.sh" "$FIRMWARE" "$ROOT/board/parameter-buildroot-fit.txt" \
	|| die "bundle exceeds GPT slot sizes"

[[ -r "$STREAM_SRC" && -r "$LIB_SRC" ]] || die "A/B stream helpers missing from repository overlay"

remote "mkdir -p $OTA_DIR && rm -f $OTA_DIR/apply.status $OTA_DIR/boot.img $OTA_DIR/boot_b.img $OTA_DIR/rootfs.img $OTA_DIR/oem.img $OTA_DIR/manifest.json $OTA_DIR/*.sha256 $STREAM $STREAM_LIB"

usb_ssh_session_run_scp "$ROOT" "$IFACE" \
	"$STREAM_SRC" "$LIB_SRC" \
	"$TARGET_USER@$TARGET_ADDR:$OTA_DIR/"

# Existing images may have wlan-wpa.service without shutdown ordering while
# wpa_supplicant may hold /userdata/wpa_supplicant/wpa_supplicant.log. USB-SSH is
# independent of wlan0, so stop that unit before writes that touch userdata status.
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
	[[ -n "$OEM_DEV" ]] || die "UPGRADE_OEM_IMG set but board has no oem partition"
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
# Arm reboots on success; SSH may drop — treat reboot as expected.
set +e
remote "nohup env LWS_HMI_AB_LIB=$STREAM_LIB /bin/sh $STREAM arm-reboot $INACTIVE >/userdata/ota/apply.log 2>&1 </dev/null & echo ARM_STARTED"
arm_rc=$?
set -e
[[ "$arm_rc" -eq 0 ]] || die "failed to start arm-reboot"

wait_line_rendered=0
# Same single-line progress style as stream-file-progress.py (stderr + \r).
# Do not pad to a fixed width: %-100s wraps on narrow terminals and \r cannot
# rewind past the wrap, so each tick looks like a new line.
clear_wait_line() {
	if [[ "$wait_line_rendered" -eq 1 ]]; then
		printf '\r\033[K' >&2
		wait_line_rendered=0
	fi
}

render_wait_line() {
	local msg="$1"
	local cols
	cols="$(tput cols 2>/dev/null || echo 80)"
	[[ "$cols" =~ ^[0-9]+$ ]] || cols=80
	((cols < 20)) && cols=20
	if ((${#msg} >= cols)); then
		msg="${msg:0:$((cols - 1))}"
	fi
	printf '\r\033[K%s' "$msg" >&2
	wait_line_rendered=1
}

upgrade_complete() {
	clear_wait_line
	bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
		"$TRANSPORT" "$IFACE" "$TARGET_ADDR" "$TARGET_SERIAL_HINT" || true
	echo "Upgrade successfully, please wait for the device to restart."
	exit 0
}

echo "Finalizing upgrade. The device will restart automatically."
deadline_down=$((SECONDS + WAIT_REBOOT_SEC))
spinner_frame=0
status_poll_tick=0
apply_status=""
while ((SECONDS < deadline_down)); do
	spinner_frame=$((spinner_frame % 3 + 1))
	case "$spinner_frame" in
	1) dots=".  " ;;
	2) dots=".. " ;;
	3) dots="..." ;;
	esac
	elapsed=$((WAIT_REBOOT_SEC - (deadline_down - SECONDS)))
	render_wait_line "  Waiting for device restart${dots} (${elapsed}s)"

	if [[ "$status_poll_tick" -eq 0 ]]; then
		if ! usb_ssh_session_run_ssh "$ROOT" "$IFACE" "true" >/dev/null 2>&1; then
			upgrade_complete
		fi

		apply_status="$(remote "cat $OTA_DIR/apply.status 2>/dev/null || true" 2>/dev/null | tr -d '\r' | head -n1 || true)"
		if [[ "$apply_status" == "fail" ]]; then
			clear_wait_line
			remote "tail -n 120 $OTA_DIR/apply.log 2>/dev/null || true" >&2 || true
			die "board arm-reboot failed (see $OTA_DIR/apply.log)"
		fi
		if [[ "$apply_status" == "ok" ]]; then
			upgrade_complete
		fi
	fi

	status_poll_tick=$(( (status_poll_tick + 1) % 4 ))
	sleep 0.25
done

clear_wait_line
remote "tail -n 120 $OTA_DIR/apply.log 2>/dev/null || true" >&2 || true
die "board did not request reboot. apply.status=${apply_status:-unknown} — check $OTA_DIR/apply.log"
