#!/bin/sh
# After try-boot: commit letter if HMI healthy, else swap boot back and reboot.
# Fresh factory boot (try_boot=0) exits 0 immediately.
set -eu

LIB=/usr/libexec/hmi/ab-slot-lib.sh
# shellcheck disable=SC1090
. "$LIB"

HMI_WAIT_SEC="${LWS_HMI_AB_HMI_WAIT_SEC:-120}"
LOG=/var/lib/hmi/ab-boot-confirm.log

mkdir -p /var/lib/hmi
# Keep journal useful; also append a file when writable.
touch "$LOG" 2>/dev/null || LOG=/dev/null
exec >>"$LOG" 2>&1

ab_log "confirm start"

# P3.2 QEMU: single virtio rootfs, no GPT PARTLABELs / misc A/B marker.
if grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null; then
	ab_log "emulator — skip A/B try-boot confirm"
	exit 0
fi

if ! ab_slot_marker_valid; then
	factory_root_letter="$(ab_current_root_letter 2>/dev/null || true)"
	if [ -z "$factory_root_letter" ]; then
		ab_log "ERROR: slot marker missing and mounted root letter is unknown"
		exit 1
	fi
	ab_slot_write "$factory_root_letter" "0" "$factory_root_letter" 0
	ab_log "initialized slot marker from mounted root letter=$factory_root_letter"
	exit 0
fi

set -- $(ab_slot_read)
active="${1:-A}"
try_boot="${2:-0}"
previous="${3:-A}"
tries="${4:-0}"

if [ "$try_boot" = "0" ]; then
	ab_log "no try-boot armed (active=$active); nothing to do"
	exit 0
fi

ab_log "try-boot=$try_boot active=$active previous=$previous tries=$tries"

root_dev="$(ab_current_root_dev 2>/dev/null || true)"
root_letter="$(ab_current_root_letter 2>/dev/null || true)"
root_matches_try=0
if [ "$root_letter" = "$try_boot" ]; then
	root_matches_try=1
else
	ab_log "ERROR: mounted root device=${root_dev:-unknown} letter=${root_letter:-unknown} expected try=$try_boot"
fi

healthy=0
i=0
while [ "$root_matches_try" -eq 1 ] && [ "$i" -lt "$HMI_WAIT_SEC" ]; do
	if systemctl is-active --quiet hmi.service 2>/dev/null; then
		healthy=1
		break
	fi
	i=$((i + 1))
	sleep 1
done

if [ "$healthy" -eq 1 ]; then
	committed_letter="$try_boot"
	ab_slot_write "$committed_letter" "0" "$previous" 0
	ab_log "COMMIT letter=$committed_letter (hmi.service active)"
	exit 0
fi

tries=$((tries - 1))
if [ "$tries" -gt 0 ]; then
	ab_slot_write "$active" "$try_boot" "$previous" "$tries"
	ab_log "HMI not healthy; tries_remaining=$tries — reboot retry"
	sync
	sleep 1
	ab_reboot
	exit 0
fi

ab_swap_boot_partitions
ab_slot_write "$previous" "0" "$previous" 0
ab_log "ROLLBACK to letter=$previous (swapped boot; HMI failed, tries exhausted)"
sync
sleep 1
ab_reboot
