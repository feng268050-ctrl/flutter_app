#!/bin/sh
# Board display/MIPI init (OEM): by-name links, private1, ParamUpdate, prefs bind.
set -u

log() { echo "display-init: $*"; }

setup_system_bin() {
	mkdir -p /system/bin
	for b in MountAll ParamUpdate MainServer; do
		[ -x "/usr/bin/$b" ] || continue
		ln -sf "/usr/bin/$b" "/system/bin/$b"
	done
}

setup_by_name_links() {
	local part name dev base

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

oem_screen_lcd_dir() {
	# param-update runs before oem-compose — read /oem/manifest.json directly.
	local screen_path
	[ -f /oem/manifest.json ] || return 1
	screen_path="$(sed -n 's/.*"screen_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' /oem/manifest.json | head -1)"
	[ -n "$screen_path" ] || return 1
	[ -d "/oem/$screen_path/lcd" ] || return 1
	printf '%s\n' "/oem/$screen_path/lcd"
}

seed_private1_params() {
	local f src_dir oem_lcd
	[ -d /mnt/private1 ] || return 0

	oem_lcd="$(oem_screen_lcd_dir)" || {
		log "ERROR: OEM screen lcd/ missing (need /oem/manifest.json + screens/.../lcd) — no /system/etc fallback"
		exit 1
	}
	src_dir="$oem_lcd"
	for f in 960_lcd_param_rk356x.txt lcd_mipi_param.txt; do
		[ -f "$src_dir/$f" ] || {
			log "ERROR: missing $src_dir/$f — no /system/etc fallback"
			exit 1
		}
	done

	log "seeding private1 LCD params from $src_dir (OEM only)"
	for f in 960_lcd_param_rk356x.txt lcd_mipi_param.txt; do
		cp -f "$src_dir/$f" "/mnt/private1/$f"
	done
	# Alias used by some Innohi ParamUpdate builds (same as post-hook 05-display).
	cp -f /mnt/private1/960_lcd_param_rk356x.txt /mnt/private1/LCD_PARAM_RK356X_V11_0.txt
	chmod -R a+rwX /mnt/private1 2>/dev/null || true
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

run_mountall() {
	# MountAll resizes rootfs on Android; on Linux / is already mounted — skip (can hang).
	log "MountAll skipped (Linux rootfs already mounted)"
}

run_paramupdate() {
	[ -x /usr/bin/ParamUpdate ] || return 0
	log "ParamUpdate create_screen_sh"
	/usr/bin/ParamUpdate create_screen_sh || log "ParamUpdate create_screen_sh failed (continuing)"
}

run_screen_sh() {
	# Innohi etc/profile.d/screen.sh — apply generated MIPI timing after ParamUpdate.
	if [ -f /mnt/private1/screen.sh ]; then
		log "running /mnt/private1/screen.sh"
		/mnt/private1/screen.sh || log "/mnt/private1/screen.sh failed (continuing)"
	elif [ -f /screen.sh ]; then
		log "running /screen.sh"
		/screen.sh || log "/screen.sh failed (continuing)"
	fi
}

wait_mmc || log "eMMC slow — continuing"
setup_by_name_links
mkdir -p /mnt/private1 /mnt/private /mnt/userdata /userdata /oem /dev/block/by-name
setup_system_bin
mount_named_part private1 /mnt/private1
mount_named_part private /mnt/private
mount_named_part oem /oem
mount_named_part userdata /userdata
# Persist prefs across rootfs flash (P2.3): /var/lib/* → /userdata/{wpa_supplicant,network,bluetooth,hmi}
if [ -x /usr/libexec/hmi/bind-prefs.sh ]; then
	/usr/libexec/hmi/bind-prefs.sh || log "prefs-bind soft-fail"
fi
seed_private1_params
run_mountall
run_paramupdate
run_screen_sh
log "done"
