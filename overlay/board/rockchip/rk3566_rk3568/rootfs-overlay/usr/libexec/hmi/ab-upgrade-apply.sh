#!/bin/sh
# Full-system A/B apply: write inactive boot+rootfs (+ optional oem), arm try-boot, reboot.
# Staging: /userdata/ota/ (boot.img + boot_b.img + rootfs.img [+ oem.img]).
# Both FITs are built and hashed separately; never patch a FIT after build.
# Vendor U-Boot loads PARTNAME=boot only — back up current FIT to boot_b,
# then write the try FIT to boot for the next reboot.
# Must NOT wipe userdata, rewrite uboot, or overwrite the active letter without staging.
set -eu

LIB="${LWS_HMI_AB_LIB:-/usr/lib/lws-hmi/ab-slot-lib.sh}"
# shellcheck disable=SC1090
. "$LIB"

OTA_DIR="${LWS_HMI_OTA_DIR:-/userdata/ota}"
MANIFEST="$OTA_DIR/manifest.json"
STATUS="$OTA_DIR/apply.status"
BOOT_IMG="$OTA_DIR/boot.img"
BOOT_B_IMG="$OTA_DIR/boot_b.img"
ROOTFS_IMG="$OTA_DIR/rootfs.img"
OEM_IMG="$OTA_DIR/oem.img"

set_status() {
	mkdir -p "$OTA_DIR"
	printf '%s\n' "$1" >"$STATUS"
	sync
}

fail() {
	ab_log "$1"
	set_status fail
	exit 1
}

case "${1:-}" in
-h|--help)
	cat <<EOF
Usage: ab-upgrade-apply.sh

Reads /userdata/ota/{manifest.json,boot.img,boot_b.img,rootfs.img[,oem.img]}.
boot.img selects rootfs_a; boot_b.img selects rootfs_b (hash-valid FITs).
Writes inactive rootfs_*, backs up boot to boot_b, writes the matching FIT to boot,
arms try-boot, then reboots.

Env: LWS_HMI_OTA_DIR (default /userdata/ota)
EOF
	exit 0
	;;
esac

set_status running
apply_complete=0
cleanup_status() {
	rc=$?
	trap - 0
	if [ "$apply_complete" -ne 1 ]; then
		set_status fail
	fi
	exit "$rc"
}
trap cleanup_status 0

[ -d /userdata ] || fail "/userdata not mounted"
[ -f "$BOOT_IMG" ] || fail "missing $BOOT_IMG"
[ -f "$BOOT_B_IMG" ] || fail "missing $BOOT_B_IMG"
[ -f "$ROOTFS_IMG" ] || fail "missing $ROOTFS_IMG"

for f in "$BOOT_IMG" "$BOOT_B_IMG" "$ROOTFS_IMG"; do
	case "$f" in
	*uboot*|*userdata/lws-hmi*) fail "refusing path $f" ;;
	esac
done

read_digest() {
	img="$1"
	# Prefer sibling .sha256 (host upgrade always writes these; no python on board).
	if [ -f "$img.sha256" ]; then
		awk 'NF{print $1; exit}' "$img.sha256"
		return 0
	fi
	base="$(basename "$img")"
	if [ -f "$MANIFEST" ]; then
		# Best-effort: first 64-hex token on a line mentioning this image name.
		d="$(grep -F "$base" "$MANIFEST" | grep -Eo '[0-9a-fA-F]{64}' | head -n1 || true)"
		if [ -n "$d" ]; then
			printf '%s\n' "$d"
			return 0
		fi
	fi
	return 1
}

verify_file() {
	img="$1"
	want="$(read_digest "$img")" || fail "missing digest for $img (need $img.sha256)"
	got="$(sha256sum "$img" | awk '{print $1}')"
	[ "$got" = "$want" ] || fail "digest mismatch for $img (want $want got $got)"
	ab_log "digest ok: $(basename "$img")"
}

verify_file "$BOOT_IMG"
verify_file "$BOOT_B_IMG"
verify_file "$ROOTFS_IMG"
if [ -f "$OEM_IMG" ]; then
	if read_digest "$OEM_IMG" >/dev/null 2>&1; then
		verify_file "$OEM_IMG"
	elif [ -f "$OEM_IMG.sha256" ]; then
		verify_file "$OEM_IMG"
	else
		ab_log "oem.img present without digest — writing without digest check"
	fi
fi

marker_valid=0
ab_slot_marker_valid && marker_valid=1
set -- $(ab_slot_read)
metadata_active="$1"
try_boot="$2"
previous="$3"
tries="$4"
current_root_dev="$(ab_current_root_dev)" \
	|| fail "cannot identify the block device mounted as /; refusing upgrade"
active="$(ab_current_root_letter)" \
	|| fail "current root is not PARTLABEL=rootfs_a/rootfs_b; refusing upgrade"
if [ "$marker_valid" -ne 1 ]; then
	ab_log "slot marker missing at safe misc offset; initializing active=$active from mounted root"
	ab_slot_write "$active" "0" "$active" 0
	metadata_active="$active"
	try_boot=0
	previous="$active"
	tries=0
fi
[ "$try_boot" = "0" ] \
	|| fail "try-boot $try_boot is still pending; wait for boot confirmation before upgrading"
[ "$metadata_active" = "$active" ] \
	|| fail "slot metadata active=$metadata_active disagrees with mounted root=$active; refusing upgrade"
inactive="$(ab_other_letter "$active")"
ab_log "mounted-root=$current_root_dev active=$active inactive=$inactive (try=$try_boot prev=$previous tries=$tries)"

# Invariant: PARTNAME=boot holds the currently running letter's FIT; boot_b holds the other.
root_lab="$(ab_rootfs_part_for_letter "$inactive")"
case "$inactive" in
A) stage_boot="$BOOT_IMG" ;;
B) stage_boot="$BOOT_B_IMG" ;;
*) fail "invalid inactive letter: $inactive" ;;
esac
root_dev="$(ab_require_part "$root_lab")"
boot_dev="$(ab_require_part boot)"
boot_b_dev="$(ab_require_part boot_b)"
if ab_same_block_device "$root_dev" "$current_root_dev"; then
	fail "refusing to overwrite mounted root device $current_root_dev ($root_lab)"
fi

uboot_dev="$(ab_part_by_label uboot 2>/dev/null || true)"
if [ -n "$uboot_dev" ]; then
	case "$boot_dev$boot_b_dev$root_dev" in
	*"$uboot_dev"*) fail "refusing to write uboot device" ;;
	esac
fi

boot_bytes="$(wc -c <"$stage_boot" | tr -d ' ')"
root_bytes="$(wc -c <"$ROOTFS_IMG" | tr -d ' ')"
boot_cap="$(ab_block_size_bytes "$boot_dev")"
root_cap="$(ab_block_size_bytes "$root_dev")"
[ "$boot_bytes" -le "$boot_cap" ] || fail "boot.img ($boot_bytes) > boot ($boot_cap)"
[ "$root_bytes" -le "$root_cap" ] || fail "rootfs.img ($root_bytes) > $root_lab ($root_cap)"

ab_log "writing $root_lab ← rootfs.img (inactive; mounted root untouched)"
dd if="$ROOTFS_IMG" of="$root_dev" bs=4M conv=fsync status=none
sync

if [ -f "$OEM_IMG" ]; then
	oem_dev="$(ab_require_part oem)"
	oem_bytes="$(wc -c <"$OEM_IMG" | tr -d ' ')"
	oem_cap="$(ab_block_size_bytes "$oem_dev")"
	[ "$oem_bytes" -le "$oem_cap" ] || fail "oem.img too large"
	ab_log "writing oem ← oem.img (single slot, no A/B)"
	dd if="$OEM_IMG" of="$oem_dev" bs=4M conv=fsync status=none
fi

# Put try FIT on PARTNAME=boot; previous FIT saved on boot_b for rollback.
# Running system is unaffected (boot raw + kernel already in RAM).
ab_arm_try_boot_fit "$stage_boot"

ab_slot_write "$active" "$inactive" "$active" "$AB_DEFAULT_TRIES"
ab_log "armed try-boot=$inactive (previous=$active tries=$AB_DEFAULT_TRIES)"
set_status ok
apply_complete=1
sync
ab_log "rebooting into try-boot letter $inactive"
sleep 1
ab_reboot
