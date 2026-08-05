#!/bin/sh
# Print KEY=VALUE A/B slot + inactive partition targets for host `make upgrade`.
# Apply/verify live in packages/cyber_ota (HMI); this is preflight-only.
set -eu

LIB="${LWS_HMI_AB_LIB:-/usr/libexec/ab/ab-slot-lib.sh}"
# shellcheck disable=SC1090
. "$LIB"

# Keep KEY=VALUE stdout clean (lib ab_log defaults to stdout).
ab_log() {
	echo "ab: $*" >&2
}

fail() {
	ab_log "$1"
	exit 1
}

[ -d /userdata ] || fail "/userdata not mounted"

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
root_lab="$(ab_rootfs_part_for_letter "$inactive")"
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

oem_dev=""
oem_cap=0
if oem_dev="$(ab_part_by_label oem 2>/dev/null)"; then
	oem_cap="$(ab_block_size_bytes "$oem_dev")"
else
	oem_dev=""
fi

root_cap="$(ab_block_size_bytes "$root_dev")"
boot_cap="$(ab_block_size_bytes "$boot_dev")"
boot_b_cap="$(ab_block_size_bytes "$boot_b_dev")"

printf 'active=%s\n' "$active"
printf 'inactive=%s\n' "$inactive"
printf 'try_boot=%s\n' "$try_boot"
printf 'previous=%s\n' "$previous"
printf 'tries=%s\n' "$tries"
printf 'current_root_dev=%s\n' "$current_root_dev"
printf 'root_lab=%s\n' "$root_lab"
printf 'root_dev=%s\n' "$root_dev"
printf 'root_cap=%s\n' "$root_cap"
printf 'boot_dev=%s\n' "$boot_dev"
printf 'boot_cap=%s\n' "$boot_cap"
printf 'boot_b_dev=%s\n' "$boot_b_dev"
printf 'boot_b_cap=%s\n' "$boot_b_cap"
printf 'oem_dev=%s\n' "$oem_dev"
printf 'oem_cap=%s\n' "$oem_cap"
printf 'fit_name=%s\n' "$( [ "$inactive" = A ] && echo boot.img || echo boot_b.img )"
