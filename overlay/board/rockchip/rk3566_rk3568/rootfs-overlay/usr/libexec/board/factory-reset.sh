#!/bin/sh
# Full userdata wipe; preserve provision partition and Rockchip Vendor Storage.
# Invoked by /usr/bin/factory-reset (user-facing 恢复出厂设置).
set -eu

. /usr/libexec/board/paths.sh

log() {
	echo "factory-reset: $*"
}

die() {
	echo "factory-reset: ERROR: $*" >&2
	exit 1
}

log "stopping user-facing services"
systemctl stop hmi.service os-settings.service 2>/dev/null || true
systemctl stop wlan-wpa.service eth0-network.service bluetooth.service 2>/dev/null || true

userdata_dev=""
if [ -b /dev/block/by-name/userdata ]; then
	userdata_dev=/dev/block/by-name/userdata
elif mountpoint -q /userdata 2>/dev/null; then
	userdata_dev="$(findmnt -n -o SOURCE --target /userdata 2>/dev/null || true)"
fi

if [ -z "$userdata_dev" ] && [ ! -d /userdata ]; then
	die "/userdata missing — cannot factory-reset"
fi

# Drop /var/lib/* → userdata symlinks so umount is clean.
for var_path in "$VAR_WPA" "$VAR_NETWORK" "$VAR_BLUETOOTH" "$VAR_HAL" "$VAR_HMI"; do
	if [ -L "$var_path" ]; then
		rm -f "$var_path"
	fi
done
# properties.ini bind to provision — restore after wipe via provision-mount on next boot.
if [ -L "$VAR_HAL/properties.ini" ]; then
	rm -f "$VAR_HAL/properties.ini"
fi

if mountpoint -q /userdata 2>/dev/null; then
	log "unmounting /userdata"
	umount /userdata 2>/dev/null || umount -l /userdata 2>/dev/null || die "failed to unmount /userdata"
fi

if [ -n "$userdata_dev" ] && [ -b "$userdata_dev" ]; then
	log "formatting userdata partition $userdata_dev"
	mkfs.ext4 -F -L userdata "$userdata_dev" >/dev/null \
		|| die "mkfs.ext4 on $userdata_dev failed"
else
	log "wiping /userdata directory (no GPT userdata partition)"
	mkdir -p /userdata
	find /userdata -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi

sync
log "userdata wiped — provision + Vendor Storage untouched; rebooting"
reboot
