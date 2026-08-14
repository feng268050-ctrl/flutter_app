#!/usr/bin/env bash
# Stamp distinct ext4 LABEL (+ random UUID) on a rootfs image file (host path).
# Used before factory pack / RockUSB di so A/B never share LABEL/UUID.
# Boot uses root=PARTLABEL=… — this is for udev by-label/by-uuid hygiene only.
#
# Usage: stamp-rootfs-ext4-identity.sh <image> <rootfs_a|rootfs_b>
set -euo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

IMG="${1:-}"
LABEL="${2:-}"
[[ -n "$IMG" && -r "$IMG" ]] || die "usage: $0 <ext4-image> <rootfs_a|rootfs_b>"
case "$LABEL" in
rootfs_a | rootfs_b) ;;
*) die "label must be rootfs_a or rootfs_b (got $LABEL)" ;;
esac

abs="$(cd "$(dirname "$IMG")" && pwd)/$(basename "$IMG")"
dir="$(dirname "$abs")"
base="$(basename "$abs")"

run_tune2fs() {
	tune2fs -L "$LABEL" -U random "$1" >/dev/null
}

if command -v tune2fs >/dev/null 2>&1; then
	run_tune2fs "$abs"
elif command -v docker >/dev/null 2>&1; then
	echo "stamp-rootfs-ext4-identity: tune2fs via Docker alpine ($base → $LABEL)" >&2
	# Alpine keeps tune2fs in e2fsprogs-extra (e2fsprogs alone → "tune2fs: not found").
	docker run --rm -v "$dir:/work" alpine:3.20 \
		sh -c "apk add --no-cache e2fsprogs e2fsprogs-extra >/dev/null && \
			tune2fs -L $LABEL -U random /work/$base >/dev/null"
else
	die "need host tune2fs or Docker to stamp $abs (no boot-time restamp)"
fi

echo "stamp-rootfs-ext4-identity: $base LABEL=$LABEL (new UUID)"
