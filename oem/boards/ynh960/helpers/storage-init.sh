#!/bin/sh
# Board storage init (OEM): partitions, provision, prefs.
set -u

log() { echo "storage-init: $*"; }

setup_by_name_links() {
	local part name base

	[ -d /sys/block/mmcblk0 ] || return 0
	mkdir -p /dev/block/by-name

	for part in /sys/block/mmcblk0/mmcblk0p*; do
		[ -d "$part" ] || continue
		name="$(sed -n 's/^PARTNAME=\(.*\)/\1/p' "$part/uevent" 2>/dev/null || true)"
		[ -n "$name" ] || continue
		base="$(basename "$part")"
		ln -sf "/dev/$base" "/dev/block/by-name/$name"
	done
}

mount_named_part() {
	local name="$1" mnt="$2"
	local dev="/dev/block/by-name/$name"

	[ -b "$dev" ] || return 0
	mkdir -p "$mnt"
	if mountpoint -q "$mnt" 2>/dev/null; then
		return 0
	fi
	if ! blkid "$dev" 2>/dev/null | grep -q 'TYPE='; then
		log "format $dev (ext4) for $mnt"
		mkfs.ext4 -F -L "$name" "$dev" >/dev/null 2>&1 || true
	fi
	mount -t ext4 -o noatime "$dev" "$mnt" 2>/dev/null \
		|| mount -o noatime "$dev" "$mnt" 2>/dev/null \
		|| log "mount $dev -> $mnt failed"
}

wait_mmc() {
	local i
	for i in $(seq 1 50); do
		[ -b /dev/mmcblk0 ] && return 0
		sleep 0.2
	done
	log "eMMC not ready"
	return 1
}

wait_mmc || log "eMMC slow — continuing"
setup_by_name_links
mkdir -p /mnt/private1 /mnt/private /mnt/userdata /userdata /oem /dev/block/by-name
mount_named_part private1 /mnt/private1
mount_named_part private /mnt/private
mount_named_part oem /oem
mount_named_part userdata /userdata
if [ -x /usr/libexec/board/provision-mount.sh ]; then
	/usr/libexec/board/provision-mount.sh || log "provision-mount soft-fail"
fi
if [ -x /usr/libexec/board/bind-prefs.sh ]; then
	/usr/libexec/board/bind-prefs.sh || log "prefs-bind soft-fail"
fi
if [ -x /usr/libexec/board/apply-datetime-prefs.sh ]; then
	/usr/libexec/board/apply-datetime-prefs.sh || log "apply-datetime-prefs soft-fail"
fi
log "done (panel timing from kernel DT)"
