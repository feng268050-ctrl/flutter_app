#!/usr/bin/env bash
# Remote full-system firmware upgrade over USB-SSH / LAN SSH (make upgrade).
# Transfers dual FIT images + rootfs (+ digests/manifest), invokes board apply, waits for reboot request.
# MUST NOT call RockUSB / upgrade_tool uf / flash-usb.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

FIRMWARE="${LWS_HMI_FIRMWARE_DIR:-$ROOT/output/firmware}"
OTA_DIR="/userdata/ota"
HELPER_SRC_DIR="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi"
APPLY_SRC="$HELPER_SRC_DIR/ab-upgrade-apply.sh"
LIB_SRC="$HELPER_SRC_DIR/ab-slot-lib.sh"
APPLY="$OTA_DIR/ab-upgrade-apply.sh"
APPLY_LIB="$OTA_DIR/ab-slot-lib.sh"
WAIT_REBOOT_SEC="${UPGRADE_WAIT_REBOOT_SEC:-300}"
WAIT_APPLY_START_SEC="${UPGRADE_WAIT_APPLY_START_SEC:-30}"
OEM_IMG="${UPGRADE_OEM_IMG:-}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<EOF
Usage: $0

Remote A/B firmware upgrade over SSH (same target selection as make push-app).

Transfers hash-valid boot.img (rootfs_a), boot_b.img (rootfs_b),
rootfs.img, and digests. Board writes the inactive boot/rootfs pair,
arms try-boot, and reboots. Includes the Linux kernel.

For app-only iteration, use make push-app.

Env:
  SERIAL / LWS_HMI_SERIAL   select board when multiple devices
  IP / LWS_HMI_IP           registered SSH only (make connect <ip>)
  LWS_HMI_FIRMWARE_DIR      default: output/firmware
  UPGRADE_OEM_IMG           optional path to oem.img for full-system bundle
  UPGRADE_WAIT_REBOOT_SEC   wait for reboot/SSH disconnect (default 300)

Does NOT enter RockUSB or run upgrade_tool uf. Use make flash for GPT/U-Boot.
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

upload_with_progress() {
	local src="$1"
	local dest="$2"
	python3 "$ROOT/scripts/stream-file-progress.py" "$src" |
		remote "cat >'$dest'"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

# Guard: never invoke flash path
case "$*" in
*flash-usb*|*upgrade_tool*|*[[:space:]]uf[[:space:]]*) die "upgrade must not use RockUSB uf" ;;
esac

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH full-system upgrade: target=$TARGET_USER@$TARGET_ADDR"
else
	echo "USB-SSH full-system upgrade: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
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
	# docker-export may leave rootfs only under SDK; try common alt
	if [[ -f "$ROOT/output/firmware/rootfs.ext2" ]]; then
		ROOTFS_IMG="$ROOT/output/firmware/rootfs.ext2"
	else
		die "missing $FIRMWARE/rootfs.img — run: make build-rootfs"
	fi
}

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/lws-hmi-upgrade.XXXXXX")"
cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

cp -f "$BOOT_IMG" "$STAGE/boot.img"
cp -f "$BOOT_B_IMG" "$STAGE/boot_b.img"
cp -f "$ROOTFS_IMG" "$STAGE/rootfs.img"
BOOT_SHA="$(sha256sum "$STAGE/boot.img" | awk '{print $1}')"
BOOT_B_SHA="$(sha256sum "$STAGE/boot_b.img" | awk '{print $1}')"
ROOT_SHA="$(sha256sum "$STAGE/rootfs.img" | awk '{print $1}')"
printf '%s  boot.img\n' "$BOOT_SHA" >"$STAGE/boot.img.sha256"
printf '%s  boot_b.img\n' "$BOOT_B_SHA" >"$STAGE/boot_b.img.sha256"
printf '%s  rootfs.img\n' "$ROOT_SHA" >"$STAGE/rootfs.img.sha256"

if [[ -n "$OEM_IMG" ]]; then
	[[ -f "$OEM_IMG" ]] || die "UPGRADE_OEM_IMG not found: $OEM_IMG"
	cp -f "$OEM_IMG" "$STAGE/oem.img"
	OEM_SHA="$(sha256sum "$STAGE/oem.img" | awk '{print $1}')"
	printf '%s  oem.img\n' "$OEM_SHA" >"$STAGE/oem.img.sha256"
fi

python3 - "$STAGE" "$BOOT_SHA" "$BOOT_B_SHA" "$ROOT_SHA" "${OEM_SHA:-}" <<'PY'
import json, sys
from pathlib import Path
stage, boot_sha, boot_b_sha, root_sha, oem_sha = sys.argv[1:6]
images = {
    "boot.img": {"sha256": boot_sha, "required": True},
    "boot_b.img": {"sha256": boot_b_sha, "required": True},
    "rootfs.img": {"sha256": root_sha, "required": True},
}
if oem_sha:
    images["oem.img"] = {"sha256": oem_sha, "required": False}
manifest = {
    "version": 1,
    "mode": "full-system",
    "slot_policy": "paired-boot-rootfs",
    "images": images,
}
Path(stage, "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
PY

echo "Bundle:"
ls -lh "$STAGE"
bash "$ROOT/scripts/verify-firmware-partitions.sh" "$STAGE" "$ROOT/board/parameter-buildroot-fit.txt" \
	|| die "bundle exceeds GPT slot sizes"

[[ -r "$APPLY_SRC" && -r "$LIB_SRC" ]] || die "A/B board helpers missing from repository overlay"
remote "mkdir -p $OTA_DIR && rm -f $OTA_DIR/apply.status $OTA_DIR/boot.img $OTA_DIR/boot_b.img $OTA_DIR/rootfs.img $OTA_DIR/oem.img $OTA_DIR/manifest.json $OTA_DIR/*.sha256 $APPLY $APPLY_LIB"

echo "Transferring firmware bundle to $OTA_DIR ..."
upload_with_progress "$STAGE/boot.img" "$OTA_DIR/boot.img"
upload_with_progress "$STAGE/boot_b.img" "$OTA_DIR/boot_b.img"
upload_with_progress "$STAGE/rootfs.img" "$OTA_DIR/rootfs.img"
usb_ssh_session_run_scp "$ROOT" "$IFACE" \
	"$STAGE/manifest.json" "$STAGE/boot.img.sha256" "$STAGE/boot_b.img.sha256" \
	"$STAGE/rootfs.img.sha256" "$APPLY_SRC" "$LIB_SRC" \
	"$TARGET_USER@$TARGET_ADDR:$OTA_DIR/"
if [[ -f "$STAGE/oem.img" ]]; then
	upload_with_progress "$STAGE/oem.img" "$OTA_DIR/oem.img"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" "$STAGE/oem.img.sha256" \
		"$TARGET_USER@$TARGET_ADDR:$OTA_DIR/"
fi

# Existing images may have lws-hmi-wpa.service without shutdown ordering while
# wpa_supplicant holds /userdata/lws-hmi/wpa_supplicant.log. USB-SSH is
# independent of wlan0, so stop that unit before apply to release userdata now.
if ! usb_ssh_session_is_remote; then
	remote "/usr/bin/systemctl.real stop lws-hmi-wpa.service >/dev/null 2>&1 || true"
fi

echo "Invoking board full-system apply (will reboot)..."
# Apply reboots on success; SSH may drop — treat reboot as expected.
set +e
remote "nohup env LWS_HMI_AB_LIB=$APPLY_LIB /bin/sh $APPLY >/userdata/ota/apply.log 2>&1 </dev/null & echo APPLY_STARTED"
apply_rc=$?
set -e
[[ "$apply_rc" -eq 0 ]] || die "failed to start board apply"

echo "Waiting for apply to start (max ${WAIT_APPLY_START_SEC}s)..."
apply_status=""
for ((i = 1; i <= WAIT_APPLY_START_SEC; i++)); do
	apply_status="$(remote "cat $OTA_DIR/apply.status 2>/dev/null || true" | tr -d '\r' | head -n1 || true)"
	if [[ "$apply_status" == "running" || "$apply_status" == "ok" || "$apply_status" == "fail" ]]; then
		break
	fi
	sleep 1
done

if [[ "$apply_status" == "fail" ]]; then
	remote "tail -n 120 $OTA_DIR/apply.log 2>/dev/null || true" >&2 || true
	die "board apply failed before reboot (see $OTA_DIR/apply.log)"
fi
if [[ "$apply_status" != "running" && "$apply_status" != "ok" ]]; then
	remote "tail -n 120 $OTA_DIR/apply.log 2>/dev/null || true" >&2 || true
	die "board apply did not start (apply.status=${apply_status:-missing})"
fi

wait_line_rendered=0
clear_wait_line() {
	if [[ "$wait_line_rendered" -eq 1 ]]; then
		printf '\r%-100s\r' ""
		wait_line_rendered=0
	fi
}

upgrade_complete() {
	clear_wait_line
	bash "$ROOT/scripts/ssh-devices.sh" dismiss-target \
		"$TRANSPORT" "$IFACE" "$TARGET_ADDR" "$TARGET_SERIAL_HINT" || true
	echo "Upgrade successfully, please wait for the device to restart."
	exit 0
}

if [[ "$apply_status" == "ok" ]]; then
	upgrade_complete
fi

echo "Finalizing upgrade. The device will restart automatically."
deadline_down=$((SECONDS + WAIT_REBOOT_SEC))
spinner_frame=0
status_poll_tick=0
while ((SECONDS < deadline_down)); do
	spinner_frame=$((spinner_frame % 3 + 1))
	case "$spinner_frame" in
	1) dots=".  " ;;
	2) dots=".. " ;;
	3) dots="..." ;;
	esac
	printf '\r  Waiting for device restart%s' "$dots"
	wait_line_rendered=1

	if [[ "$status_poll_tick" -eq 0 ]]; then
		if ! usb_ssh_session_run_ssh "$ROOT" "$IFACE" "true" >/dev/null 2>&1; then
			upgrade_complete
		fi

		apply_status="$(remote "cat $OTA_DIR/apply.status 2>/dev/null || true" | tr -d '\r' | head -n1 || true)"
		if [[ "$apply_status" == "fail" ]]; then
			clear_wait_line
			remote "tail -n 120 $OTA_DIR/apply.log 2>/dev/null || true" >&2 || true
			die "board apply failed before reboot (see $OTA_DIR/apply.log)"
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
