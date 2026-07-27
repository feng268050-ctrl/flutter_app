#!/bin/sh
# Thin rootfs stub — board display-init lives on OEM (W2).
# param-update.service runs before oem-compose; mount /oem then hand off.
set -u

log() { echo "ynh960-display-init: $*"; }

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

mount_oem() {
	local dev="/dev/block/by-name/oem"
	mkdir -p /oem
	[ -b "$dev" ] || return 1
	if mountpoint -q /oem 2>/dev/null; then
		return 0
	fi
	if ! blkid "$dev" 2>/dev/null | grep -q 'TYPE='; then
		log "format $dev (ext4) for /oem"
		mkfs.ext4 -F -L oem "$dev" >/dev/null 2>&1 || true
	fi
	mount -t ext4 -o noatime "$dev" /oem 2>/dev/null \
		|| mount -o noatime "$dev" /oem 2>/dev/null \
		|| return 1
	return 0
}

wait_mmc() {
	local i
	for i in $(seq 1 50); do
		[ -b /dev/mmcblk0 ] && return 0
		sleep 0.2
	done
	return 1
}

wait_mmc || log "eMMC slow — continuing"
setup_by_name_links
mount_oem || {
	log "ERROR: oem mount failed — cannot run board display-init"
	exit 1
}

HELPER=""
if [ -f /oem/manifest.json ]; then
	board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
	cand="/oem/${board_path}/helpers/display-init.sh"
	[ -n "$board_path" ] && [ -x "$cand" ] && HELPER="$cand"
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	log "OEM display-init missing — cannot continue"
	exit 1
fi
exec "$HELPER" "$@"
