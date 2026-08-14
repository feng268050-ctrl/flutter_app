#!/bin/sh
# Thin rootfs stub — board storage-init lives on OEM.
# storage-init.service runs before oem-compose; mount /oem then hand off.
# Emulator (lws.emulator=1 / virtio oem disk): mount /dev/vdb; skip if no helper (sim).
set -u

log() { echo "storage-init: $*"; }

is_emulator() {
	grep -q 'lws.emulator=1' /proc/cmdline 2>/dev/null && return 0
	[ -d /sys/firmware/qemu_fw_cfg ] && return 0
	return 1
}

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

mount_oem_dev() {
	local dev="$1"
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

mount_oem() {
	local dev="/dev/block/by-name/oem"
	if [ -b "$dev" ]; then
		mount_oem_dev "$dev" && return 0
	fi
	# P3.2 QEMU: second virtio disk is oem.img
	if [ -b /dev/vdb ]; then
		log "mounting emulator oem disk /dev/vdb"
		mount_oem_dev /dev/vdb && return 0
	fi
	return 1
}

wait_mmc() {
	local i
	for i in $(seq 1 50); do
		[ -b /dev/mmcblk0 ] && return 0
		sleep 0.2
	done
	return 1
}

if is_emulator; then
	log "emulator boot — skip eMMC wait"
else
	wait_mmc || log "eMMC slow — continuing"
	setup_by_name_links
fi

mount_oem || {
	log "ERROR: oem mount failed — cannot run board storage-init"
	exit 1
}

HELPER=""
board_id=""
if [ -f /oem/manifest.json ]; then
	board_path="$(sed -n 's/.*"board_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
	board_id="$(sed -n 's/.*"board_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
	cand="/oem/${board_path}/helpers/storage-init.sh"
	[ -n "$board_path" ] && [ -x "$cand" ] && HELPER="$cand"
	if [ -z "$HELPER" ] && [ -n "$board_path" ]; then
		legacy="/oem/${board_path}/helpers/display-init.sh"
		if [ -x "$legacy" ]; then
			log "WARN: OEM still ships helpers/display-init.sh — rename to storage-init.sh"
			HELPER="$legacy"
		fi
	fi
fi
if [ -z "$HELPER" ] || [ ! -x "$HELPER" ]; then
	# sim_virt: mount-only is enough.
	if [ "$board_id" = "sim" ] || is_emulator; then
		log "no OEM storage-init (board_id=${board_id:-?}) — mount-only on emulator/sim"
		exit 0
	fi
	log "OEM storage-init missing — cannot continue"
	exit 1
fi
exec "$HELPER" "$@"
