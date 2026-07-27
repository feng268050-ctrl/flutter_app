#!/bin/sh
# Stream apply helpers for developer make upgrade (SSH stdin → partitions).
# Online OTA must use ab-upgrade-apply.sh (stage under /userdata/ota/, digest, then dd).
# Must NOT wipe userdata, rewrite uboot, or overwrite the mounted root.
set -eu

LIB="${LWS_HMI_AB_LIB:-/usr/libexec/hmi/ab-slot-lib.sh}"
# shellcheck disable=SC1090
. "$LIB"

# Keep KEY=VALUE preflight stdout clean (lib ab_log defaults to stdout).
ab_log() {
	echo "ab: $*" >&2
}

OTA_DIR="${LWS_HMI_OTA_DIR:-/userdata/ota}"
STATUS="$OTA_DIR/apply.status"

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

usage() {
	cat <<EOF
Usage: ab-upgrade-stream.sh <command> [args]

Commands:
  preflight              Print KEY=VALUE slot + partition targets (safe to call anytime)
  set-status <state>     Write apply.status (running|ok|fail)
  write <dev> <bytes>    Read exactly <bytes> from stdin into block device <dev>
  backup-boot            Copy running FIT boot → boot_b (rollback copy)
  arm-reboot <letter>    Arm try-boot to <letter> (A|B), set ok, reboot
  plain-reboot           Reboot without A/B letter switch (OEM-only upgrade)

Env: LWS_HMI_AB_LIB, LWS_HMI_OTA_DIR
EOF
}

resolve_slot_state() {
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

	ACTIVE="$active"
	INACTIVE="$inactive"
	TRY_BOOT="$try_boot"
	PREVIOUS="$previous"
	TRIES="$tries"
	CURRENT_ROOT_DEV="$current_root_dev"
	ROOT_LAB="$root_lab"
	ROOT_DEV="$root_dev"
	BOOT_DEV="$boot_dev"
	BOOT_B_DEV="$boot_b_dev"
	OEM_DEV="$oem_dev"
	ROOT_CAP="$root_cap"
	BOOT_CAP="$boot_cap"
	BOOT_B_CAP="$boot_b_cap"
	OEM_CAP="$oem_cap"
}

cmd_preflight() {
	resolve_slot_state
	# Machine-readable for host upgrade-remote.sh (one KEY=VALUE per line).
	printf 'active=%s\n' "$ACTIVE"
	printf 'inactive=%s\n' "$INACTIVE"
	printf 'try_boot=%s\n' "$TRY_BOOT"
	printf 'previous=%s\n' "$PREVIOUS"
	printf 'tries=%s\n' "$TRIES"
	printf 'current_root_dev=%s\n' "$CURRENT_ROOT_DEV"
	printf 'root_lab=%s\n' "$ROOT_LAB"
	printf 'root_dev=%s\n' "$ROOT_DEV"
	printf 'root_cap=%s\n' "$ROOT_CAP"
	printf 'boot_dev=%s\n' "$BOOT_DEV"
	printf 'boot_cap=%s\n' "$BOOT_CAP"
	printf 'boot_b_dev=%s\n' "$BOOT_B_DEV"
	printf 'boot_b_cap=%s\n' "$BOOT_B_CAP"
	printf 'oem_dev=%s\n' "$OEM_DEV"
	printf 'oem_cap=%s\n' "$OEM_CAP"
	printf 'fit_name=%s\n' "$( [ "$INACTIVE" = A ] && echo boot.img || echo boot_b.img )"
}

cmd_set_status() {
	case "${1:-}" in
	running|ok|fail) set_status "$1" ;;
	*) fail "set-status: expected running|ok|fail" ;;
	esac
}

# Write exactly EXPECT bytes from stdin to DEST. Refuse short streams.
cmd_write() {
	dest="${1:-}"
	expect="${2:-}"
	[ -n "$dest" ] && [ -n "$expect" ] || fail "usage: write <dev> <bytes>"
	case "$expect" in
	*[!0-9]*|"") fail "write: bytes must be a non-negative integer" ;;
	esac
	[ -b "$dest" ] || fail "write: not a block device: $dest"

	resolve_slot_state
	allowed=0
	case "$dest" in
	"$ROOT_DEV"|"$BOOT_DEV") allowed=1 ;;
	esac
	if [ -n "$OEM_DEV" ] && [ "$dest" = "$OEM_DEV" ]; then
		allowed=1
	fi
	[ "$allowed" -eq 1 ] || fail "write: refusing device $dest (not inactive rootfs/boot/oem target)"

	if ab_same_block_device "$dest" "$CURRENT_ROOT_DEV"; then
		fail "write: refusing mounted root $dest"
	fi
	if [ -n "$uboot_dev" ] && ab_same_block_device "$dest" "$uboot_dev"; then
		fail "write: refusing uboot device"
	fi

	[ "$expect" -le "$(ab_block_size_bytes "$dest")" ] \
		|| fail "write: $expect bytes exceeds capacity of $dest"

	fifo="/tmp/ab-stream-write.$$"
	rm -f "$fifo"
	mkfifo "$fifo"
	dd_pid=""
	cleanup_fifo() {
		rm -f "$fifo"
		if [ -n "$dd_pid" ]; then
			wait "$dd_pid" 2>/dev/null || true
		fi
	}
	trap cleanup_fifo 0

	dd if="$fifo" of="$dest" bs=4M conv=fsync status=none &
	dd_pid=$!
	# Count bytes copied from SSH stdin into the fifo (and thus toward dest).
	written="$(dd bs=4M status=none | tee "$fifo" | wc -c | tr -d ' ')"
	wait "$dd_pid" || fail "write: dd to $dest failed"
	dd_pid=""
	trap - 0
	rm -f "$fifo"

	[ "$written" = "$expect" ] \
		|| fail "write: short stream to $dest (got $written want $expect); try-boot not armed"
	sync
	ab_log "wrote $written bytes → $dest"
}

cmd_backup_boot() {
	resolve_slot_state
	ab_log "backing up FIT boot → boot_b (rollback copy)"
	dd if="$BOOT_DEV" of="$BOOT_B_DEV" bs=4M status=none conv=fsync
	sync
}

cmd_arm_reboot() {
	inactive="$(ab_normalize_letter "${1:-}")"
	resolve_slot_state
	[ "$inactive" = "$INACTIVE" ] \
		|| fail "arm-reboot: letter $inactive != current inactive $INACTIVE"
	active="$ACTIVE"
	ab_slot_write "$active" "$inactive" "$active" "$AB_DEFAULT_TRIES"
	ab_log "armed try-boot=$inactive (previous=$active tries=$AB_DEFAULT_TRIES)"
	set_status ok
	sync
	ab_log "rebooting into try-boot letter $inactive"
	sleep 1
	ab_reboot
}

# Plain reboot (OEM-only upgrade): no misc try-boot arming.
cmd_plain_reboot() {
	set_status ok
	sync
	ab_log "rebooting (no A/B letter switch)"
	sleep 1
	ab_reboot
}

case "${1:-}" in
-h|--help|"") usage; exit 0 ;;
preflight) shift; cmd_preflight "$@" ;;
set-status) shift; cmd_set_status "$@" ;;
write) shift; cmd_write "$@" ;;
backup-boot) shift; cmd_backup_boot "$@" ;;
arm-reboot) shift; cmd_arm_reboot "$@" ;;
plain-reboot) shift; cmd_plain_reboot "$@" ;;
*) fail "unknown command: $1" ;;
esac
