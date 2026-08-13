#!/bin/sh
# Mount PARTLABEL=provision → /mnt/provision; bind properties.ini before HAL/App reads tunables.
# Hardware: GPT by-name. Emulator: virtio /dev/vdc (vda=root, vdb=oem).
# mkfs ext4 only when partition is unformatted. Never format on factory-reset / repeat flash.
set -eu

. /usr/libexec/board/paths.sh

log() {
	echo "provision-mount: $*"
}

resolve_provision_dev() {
	if [ -b /dev/block/by-name/provision ]; then
		printf '%s' /dev/block/by-name/provision
		return 0
	fi
	# P3.2 QEMU: third virtio disk (provision.img).
	if [ -b /dev/vdc ]; then
		printf '%s' /dev/vdc
		return 0
	fi
	dev="$(blkid -o device -t PARTLABEL=provision 2>/dev/null | head -1 || true)"
	if [ -n "$dev" ] && [ -b "$dev" ]; then
		printf '%s' "$dev"
		return 0
	fi
	return 1
}

mount_provision() {
	local dev
	dev="$(resolve_provision_dev 2>/dev/null || true)"
	[ -n "$dev" ] || {
		log "no provision device — skip"
		return 0
	}
	mkdir -p "$PROVISION_MNT"
	if mountpoint -q "$PROVISION_MNT" 2>/dev/null; then
		return 0
	fi
	if ! blkid "$dev" 2>/dev/null | grep -q 'TYPE='; then
		log "format $dev (ext4) for $PROVISION_MNT"
		mkfs.ext4 -F -L provision "$dev" >/dev/null 2>&1 || true
	fi
	if ! mount -t ext4 -o noatime "$dev" "$PROVISION_MNT" 2>/dev/null \
		&& ! mount -o noatime "$dev" "$PROVISION_MNT" 2>/dev/null; then
		# GPT adoption: partition may carry a stale superblock (wrong LABEL) from
		# repartition without mkfs — only reformat when label is not provision.
		if ! blkid "$dev" 2>/dev/null | grep -q 'LABEL="provision"'; then
			log "format $dev (ext4) — mount failed or wrong LABEL (provision adopt)"
			mkfs.ext4 -F -L provision "$dev" >/dev/null 2>&1 || true
		fi
		mount -t ext4 -o noatime "$dev" "$PROVISION_MNT" 2>/dev/null \
			|| mount -o noatime "$dev" "$PROVISION_MNT" 2>/dev/null \
			|| {
				log "mount $dev -> $PROVISION_MNT failed"
				return 1
			}
	fi
	log "mounted $dev -> $PROVISION_MNT"
}

migrate_properties_to_provision() {
	local props_var="$VAR_HAL/properties.ini"
	local legacy_userdata="$USERDATA_HAL/properties.ini"

	mkdir -p "$VAR_HAL" "$PROVISION_MNT"

	if [ ! -f "$PROPERTIES_ON_PROVISION" ] && [ -f "$legacy_userdata" ]; then
		log "migrate $legacy_userdata -> $PROPERTIES_ON_PROVISION"
		cp -a "$legacy_userdata" "$PROPERTIES_ON_PROVISION"
		rm -f "$legacy_userdata"
	fi

	if [ ! -f "$PROPERTIES_ON_PROVISION" ] && [ -f "$props_var" ] && [ ! -L "$props_var" ]; then
		log "migrate $props_var -> $PROPERTIES_ON_PROVISION"
		cp -a "$props_var" "$PROPERTIES_ON_PROVISION"
		rm -f "$props_var"
	fi
}

bind_properties_ini() {
	local props_var="$VAR_HAL/properties.ini"

	migrate_properties_to_provision

	if [ -L "$props_var" ]; then
		target="$(readlink "$props_var" 2>/dev/null || true)"
		if [ "$target" = "$PROPERTIES_ON_PROVISION" ]; then
			return 0
		fi
		rm -f "$props_var"
	fi
	if [ -e "$props_var" ] && [ ! -L "$props_var" ]; then
		if [ ! -f "$PROPERTIES_ON_PROVISION" ]; then
			cp -a "$props_var" "$PROPERTIES_ON_PROVISION"
		fi
		rm -f "$props_var"
	fi
	mkdir -p "$VAR_HAL"
	ln -sfn "$PROPERTIES_ON_PROVISION" "$props_var"
	log "bound $props_var -> $PROPERTIES_ON_PROVISION"
}

mount_provision
bind_properties_ini
exit 0
