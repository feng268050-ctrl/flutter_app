#!/bin/sh
# Resolve A/B partition nodes by PARTLABEL. Shared by upgrade helpers.
# Pure shell — no python (not shipped on lws_hmi rootfs).
# See docs/ab-slot-misc.md.
set -eu

# Keep clear of Android/vendor boot-control data at 0x0800. Vendor U-Boot
# rewrites that area during every boot on ynh960.
AB_MISC_OFFSET=1048576
AB_DEFAULT_TRIES=3

ab_die() {
	echo "lws-hmi-ab: ERROR: $*" >&2
	exit 1
}

ab_log() {
	echo "lws-hmi-ab: $*"
}

ab_part_by_label() {
	label="$1"
	node="/dev/disk/by-partlabel/$label"
	if [ -b "$node" ]; then
		printf '%s\n' "$node"
		return 0
	fi
	for d in /sys/class/block/mmcblk*p*; do
		[ -e "$d/partition" ] || continue
		name=""
		[ -r "$d/uevent" ] && name="$(sed -n 's/^PARTNAME=//p' "$d/uevent" | head -n1)"
		if [ "$name" = "$label" ]; then
			printf '/dev/%s\n' "$(basename "$d")"
			return 0
		fi
	done
	return 1
}

ab_require_part() {
	label="$1"
	node="$(ab_part_by_label "$label")" || ab_die "partition PARTLABEL=$label not found"
	printf '%s\n' "$node"
}

ab_block_size_bytes() {
	dev="$1"
	resolved="$(readlink -f "$dev" 2>/dev/null || printf '%s\n' "$dev")"
	name="$(basename "$resolved")"
	sectors_file="/sys/class/block/$name/size"
	if [ -r "$sectors_file" ]; then
		sectors="$(cat "$sectors_file")"
		printf '%s\n' "$((sectors * 512))"
		return 0
	fi
	if command -v blockdev >/dev/null 2>&1; then
		blockdev --getsize64 "$dev"
		return 0
	fi
	ab_die "cannot determine size of $dev"
}

ab_current_root_dev() {
	# /dev/root is not reliable enough to identify the backing partition.
	# mountinfo field 3 is major:minor and field 5 is the mount point.
	ab_root_majmin="$(awk '$5 == "/" {print $3; exit}' /proc/self/mountinfo 2>/dev/null)"
	[ -n "$ab_root_majmin" ] || return 1
	ab_root_sys="$(readlink -f "/sys/dev/block/$ab_root_majmin" 2>/dev/null || true)"
	[ -n "$ab_root_sys" ] || return 1
	ab_root_name="$(basename "$ab_root_sys")"
	[ -b "/dev/$ab_root_name" ] || return 1
	printf '/dev/%s\n' "$ab_root_name"
}

ab_part_label_for_dev() {
	ab_label_dev="$(readlink -f "$1" 2>/dev/null || printf '%s\n' "$1")"
	ab_label_name="$(basename "$ab_label_dev")"
	ab_label_sys="/sys/class/block/$ab_label_name/uevent"
	[ -r "$ab_label_sys" ] || return 1
	sed -n 's/^PARTNAME=//p' "$ab_label_sys" | head -n1
}

ab_current_root_letter() {
	ab_current_dev="$(ab_current_root_dev)" || return 1
	ab_current_label="$(ab_part_label_for_dev "$ab_current_dev")" || return 1
	case "$ab_current_label" in
	rootfs_a) echo A ;;
	rootfs_b) echo B ;;
	*) return 1 ;;
	esac
}

ab_same_block_device() {
	ab_same_a="$(readlink -f "$1" 2>/dev/null || printf '%s\n' "$1")"
	ab_same_b="$(readlink -f "$2" 2>/dev/null || printf '%s\n' "$2")"
	[ "$ab_same_a" = "$ab_same_b" ]
}

ab_other_letter() {
	case "$1" in
	A|a) echo B ;;
	B|b) echo A ;;
	*) ab_die "invalid letter: $1" ;;
	esac
}

ab_normalize_letter() {
	case "$1" in
	A|a) echo A ;;
	B|b) echo B ;;
	*) ab_die "invalid letter: $1" ;;
	esac
}

ab_byte_chr() {
	# decimal byte → single char (65→A). Uses printf %b octal.
	printf '%b' "$(printf '\\%03o' "$1")"
}

ab_ord() {
	# single ASCII char → decimal (A→65). od -tu1
	printf '%s' "$1" | od -An -tu1 | tr -d ' '
}

# Print: active try_boot previous tries_remaining
# On any read failure → factory default "A 0 A 0" (never fail confirm on fresh boot).
ab_slot_marker_valid() {
	ab_valid_misc="$(ab_part_by_label misc)" || return 1
	ab_valid_tmp="/tmp/lws-ab-valid.$$"
	if ! dd if="$ab_valid_misc" of="$ab_valid_tmp" bs=1 skip="$AB_MISC_OFFSET" count=8 status=none 2>/dev/null; then
		rm -f "$ab_valid_tmp"
		return 1
	fi
	ab_valid_hex="$(od -An -tx1 -N 8 "$ab_valid_tmp" 2>/dev/null | tr -d ' \n')"
	rm -f "$ab_valid_tmp"
	[ "$ab_valid_hex" = "4c57534142000100" ]
}

ab_slot_read() {
	misc="$(ab_part_by_label misc)" || {
		echo "A 0 A 0"
		return 0
	}
	tmp="/tmp/lws-ab-rd.$$"
	if ! dd if="$misc" of="$tmp" bs=1 skip="$AB_MISC_OFFSET" count=16 status=none 2>/dev/null; then
		rm -f "$tmp"
		echo "A 0 A 0"
		return 0
	fi
	magic_hex="$(od -An -tx1 -N 5 "$tmp" 2>/dev/null | tr -d ' \n')"
	if [ "$magic_hex" != "4c57534142" ]; then
		rm -f "$tmp"
		echo "A 0 A 0"
		return 0
	fi
	active_b="$(od -An -tu1 -j 8 -N 1 "$tmp" | tr -d ' ')"
	try_b="$(od -An -tu1 -j 9 -N 1 "$tmp" | tr -d ' ')"
	prev_b="$(od -An -tu1 -j 10 -N 1 "$tmp" | tr -d ' ')"
	tries_b="$(od -An -tu1 -j 11 -N 1 "$tmp" | tr -d ' ')"
	rm -f "$tmp"
	case "$active_b" in 65) active=A ;; 66) active=B ;; *) active=A ;; esac
	case "$try_b" in 0|48) try_boot=0 ;; 65) try_boot=A ;; 66) try_boot=B ;; *) try_boot=0 ;; esac
	case "$prev_b" in 65) previous=A ;; 66) previous=B ;; *) previous=A ;; esac
	echo "$active" "$try_boot" "$previous" "${tries_b:-0}"
}

# Write LWS AB block at misc offset 1 MiB. CRC omitted in on-device format v1
# (magic + fields); host factory misc.img still writes CRC for tooling.
ab_slot_write() {
	active="$(ab_normalize_letter "$1")"
	try_boot="$2"
	previous="$(ab_normalize_letter "$3")"
	tries="${4:-0}"
	case "$try_boot" in
	0|A|B) ;;
	a) try_boot=A ;;
	b) try_boot=B ;;
	*) ab_die "invalid try_boot: $try_boot" ;;
	esac
	misc="$(ab_require_part misc)"
	tmp="/tmp/lws-ab-wr.$$"
	{
		printf 'LWSAB'
		printf '\0\1\0'
		printf '%s' "$active"
		if [ "$try_boot" = "0" ]; then
			printf '\0'
		else
			printf '%s' "$try_boot"
		fi
		printf '%s' "$previous"
		ab_byte_chr "$((tries & 255))"
		# 4-byte CRC placeholder + 48 reserved (zeros) — keep block 64 bytes
		dd if=/dev/zero bs=1 count=52 status=none 2>/dev/null
	} >"$tmp"
	dd if="$tmp" of="$misc" bs=1 seek="$AB_MISC_OFFSET" conv=notrunc status=none
	sync
	rm -f "$tmp"
}

ab_refuse_userdata_wipe() {
	case "$*" in
	*userdata*|*lws-hmi*)
		ab_die "refusing userdata / prefs path: $*"
		;;
	esac
}

ab_boot_part_for_letter() {
	case "$(ab_normalize_letter "$1")" in
	A) echo boot ;;
	B) echo boot_b ;;
	esac
}

ab_rootfs_part_for_letter() {
	case "$(ab_normalize_letter "$1")" in
	A) echo rootfs_a ;;
	B) echo rootfs_b ;;
	esac
}

ab_reboot() {
	sync
	# The apply process is started with its log on /userdata. Close inherited
	# descriptors before shutdown so systemd can unmount /userdata cleanly.
	exec </dev/null >/dev/null 2>&1
	if [ -x /usr/bin/systemctl.real ]; then
		exec /usr/bin/systemctl.real reboot --no-block
	fi
	exec systemctl reboot --no-block
}

# Swap partition contents: boot ↔ boot_b (both 64 MiB).
# After swap, PARTNAME=boot holds the former boot_b image (what U-Boot will load).
ab_swap_boot_partitions() {
	boot_dev="$(ab_require_part boot)"
	boot_b_dev="$(ab_require_part boot_b)"
	tmp="/userdata/ota/.boot-swap.tmp"
	mkdir -p /userdata/ota
	ab_log "swapping boot ↔ boot_b (U-Boot loads PARTNAME=boot)"
	dd if="$boot_dev" of="$tmp" bs=4M status=none conv=fsync
	dd if="$boot_b_dev" of="$boot_dev" bs=4M status=none conv=fsync
	dd if="$tmp" of="$boot_b_dev" bs=4M status=none conv=fsync
	rm -f "$tmp"
	sync
}

# Stage try-boot: backup running FIT to boot_b, write new FIT to boot (no swap).
# U-Boot always loads PARTNAME=boot on next reboot; running kernel is unaffected.
ab_arm_try_boot_fit() {
	img="$1"
	boot_dev="$(ab_require_part boot)"
	boot_b_dev="$(ab_require_part boot_b)"
	[ -f "$img" ] || ab_die "missing try FIT: $img"
	ab_log "backing up FIT boot → boot_b (rollback copy)"
	dd if="$boot_dev" of="$boot_b_dev" bs=4M status=none conv=fsync
	ab_log "writing try FIT → boot (U-Boot loads on reboot)"
	dd if="$img" of="$boot_dev" bs=4M status=none conv=fsync
	sync
}
