#!/bin/sh
# Stamp ext4 rootfs identity so A/B never share LABEL=/UUID.
# Duplicate LABEL + UUID makes /dev/disk/by-label|by-uuid point at one slot
# only — tooling hygiene. Boot uses root=PARTLABEL=rootfs_{a|b}, not LABEL.
#
# Called at write time:
#   - packages/cyber_ota after dd of inactive rootfs
#   - host scripts/stamp-rootfs-ext4-identity.sh (factory / RockUSB)
# Manual repair (SSH): ab-rootfs-identity.sh ensure
# There is NO boot-time systemd unit (boot KPI / lean appliance).
#
# Usage:
#   ab-rootfs-identity.sh <block-or-image> <A|B>
#   ab-rootfs-identity.sh ensure
set -eu

LIB=/usr/libexec/ab/ab-slot-lib.sh
# shellcheck disable=SC1090
[ -f "$LIB" ] && . "$LIB"

log() { echo "ab-rootfs-identity: $*" >&2; }

# BusyBox / older blkid may ignore -o value; parse KEY="..." from full line.
blkid_field() {
	dev="$1"
	key="$2"
	blkid "$dev" 2>/dev/null | sed -n "s/.*${key}=\"\([^\"]*\)\".*/\1/p" | head -n1
}

stamp_one() {
	dev="$1"
	letter="$2"
	case "$(printf '%s' "$letter" | tr 'ab' 'AB')" in
	A) label=rootfs_a ;;
	B) label=rootfs_b ;;
	*)
		log "bad letter '$letter' (want A|B)"
		return 1
		;;
	esac
	[ -e "$dev" ] || {
		log "missing $dev"
		return 1
	}
	command -v tune2fs >/dev/null 2>&1 || {
		log "tune2fs not found"
		return 1
	}
	# LABEL first (safe on mounted), then new UUID (tune2fs supports mounted ext4).
	tune2fs -L "$label" "$dev" >/dev/null
	tune2fs -U random "$dev" >/dev/null
	log "stamped $dev LABEL=$label (new UUID)"
}

ensure_both() {
	command -v blkid >/dev/null 2>&1 || {
		log "blkid missing; skip"
		return 0
	}
	# Prefer ab_part_by_label (sysfs PARTNAME fallback) — by-partlabel udev
	# links may be missing early or after flash.
	if command -v ab_part_by_label >/dev/null 2>&1; then
		a_dev="$(ab_part_by_label rootfs_a 2>/dev/null || true)"
		b_dev="$(ab_part_by_label rootfs_b 2>/dev/null || true)"
	else
		a_dev="$(readlink -f /dev/disk/by-partlabel/rootfs_a 2>/dev/null || true)"
		b_dev="$(readlink -f /dev/disk/by-partlabel/rootfs_b 2>/dev/null || true)"
	fi
	[ -n "$a_dev" ] && [ -n "$b_dev" ] || {
		log "rootfs_a/b not found; skip"
		return 0
	}
	a_uuid="$(blkid_field "$a_dev" UUID)"
	b_uuid="$(blkid_field "$b_dev" UUID)"
	a_lab="$(blkid_field "$a_dev" LABEL)"
	b_lab="$(blkid_field "$b_dev" LABEL)"
	need_label=0
	need_uuid=0
	if [ -n "$a_uuid" ] && [ "$a_uuid" = "$b_uuid" ]; then
		need_uuid=1
		log "UUID collision ($a_uuid) on $a_dev and $b_dev"
	fi
	if [ "$a_lab" != "rootfs_a" ] || [ "$b_lab" != "rootfs_b" ]; then
		need_label=1
		log "LABEL mismatch (a='$a_lab' b='$b_lab')"
	fi
	[ "$need_label" -eq 1 ] || [ "$need_uuid" -eq 1 ] || {
		log "ok (LABEL/UUID already distinct)"
		return 0
	}
	fix_label() {
		dev="$1"
		letter="$2"
		case "$letter" in
		A) want=rootfs_a ;;
		B) want=rootfs_b ;;
		*) return 1 ;;
		esac
		cur="$(blkid_field "$dev" LABEL)"
		[ "$cur" = "$want" ] || tune2fs -L "$want" "$dev" >/dev/null
	}
	fix_uuid_if_needed() {
		dev="$1"
		[ "$need_uuid" -eq 1 ] || return 0
		tune2fs -U random "$dev" >/dev/null
	}
	cur=""
	if command -v ab_current_root_letter >/dev/null 2>&1; then
		cur="$(ab_current_root_letter 2>/dev/null || true)"
	fi
	case "$cur" in
	A)
		fix_label "$b_dev" B
		fix_uuid_if_needed "$b_dev"
		fix_label "$a_dev" A
		fix_uuid_if_needed "$a_dev"
		;;
	B)
		fix_label "$a_dev" A
		fix_uuid_if_needed "$a_dev"
		fix_label "$b_dev" B
		fix_uuid_if_needed "$b_dev"
		;;
	*)
		fix_label "$a_dev" A
		fix_uuid_if_needed "$a_dev"
		fix_label "$b_dev" B
		fix_uuid_if_needed "$b_dev"
		;;
	esac
	log "ensure done (label=$need_label uuid=$need_uuid)"
	udevadm trigger --subsystem-match=block 2>/dev/null || true
	udevadm settle 2>/dev/null || true
}

case "${1:-}" in
ensure)
	ensure_both
	;;
"")
	echo "usage: $0 <block-or-image> <A|B> | $0 ensure" >&2
	exit 2
	;;
*)
	stamp_one "$1" "${2:?letter A|B}"
	;;
esac
