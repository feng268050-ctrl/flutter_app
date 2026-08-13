#!/usr/bin/env bash
# Assemble P3.2 emulator bundle from *device* OS artifacts:
#   Image (make build-kernel) + rootfs.img (make build-rootfs) + sim_virt oem.img
# Does NOT build a separate virt userspace rootfs.
#
# Emulator rootfs is a fixed-size grown *copy* of the device 600M image (1536M)
# so debug-app / push-app have headroom. Device OTA artifact stays 600M.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/output/firmware/emulator"
FW="$ROOT/output/firmware"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve
# Fixed emulator-only size (not an operator knob — do not grow casually).
EMU_ROOTFS_SIZE="1536M"

die() { echo "ERROR: $*" >&2; exit 1; }
log() { echo "build-emulator: $*"; }
warn() { echo "build-emulator: WARNING: $*" >&2; }

mkdir -p "$OUT"

# OEM
log "ensuring sim_virt oem.img"
OEM_ID=sim_virt bash "$ROOT/scripts/build-oem.sh"
OEM_IMG="$ROOT/oem/out/sim_virt/oem.img"
[[ -r "$OEM_IMG" ]] || die "missing $OEM_IMG"

# Kernel Image (same as FIT)
IMAGE=""
for candidate in "$FW/Image" "$FW/emulator/Image"; do
	if [[ -r "$candidate" ]]; then
		IMAGE="$candidate"
		break
	fi
done
[[ -n "$IMAGE" ]] || die "missing $FW/Image — run: make build-kernel (publishes bare Image with FITs)"

# Rootfs
ROOTFS="$APP_ROOTFS_IMG"
[[ -f "$ROOTFS" ]] || ROOTFS="$FW/rootfs.img"
[[ -f "$ROOTFS" ]] || {
	echo "ERROR: missing $APP_ROOTFS_IMG — run: APP=$APP make build-rootfs" >&2
	exit 1
}
[[ -r "$ROOTFS" ]] || die "missing $ROOTFS — run: make build-rootfs"

log "staging $OUT"
rm -f "$OUT/Image" "$OUT/rootfs.img" "$OUT/oem.img"
cp -Lf "$IMAGE" "$OUT/Image"
# Always copy (never hardlink): grow must not mutate the device OTA rootfs.img.
cp -Lf "$ROOTFS" "$OUT/rootfs.img"
cp -Lf "$OEM_IMG" "$OUT/oem.img"

# Per-developer virtio provision disk (4 MiB ext4); identity + tunables survive
# routine build-emulator. FORCE=1 recreates an empty disk (new SN on next boot).
PROVISION_IMG="$OUT/provision.img"
if [[ "${FORCE:-0}" == "1" ]]; then
	rm -f "$PROVISION_IMG"
	log "FORCE=1 — recreating $PROVISION_IMG"
fi
if [[ ! -f "$PROVISION_IMG" ]]; then
	log "creating $PROVISION_IMG (4 MiB ext4)"
	truncate -s 4194304 "$PROVISION_IMG"
	if command -v docker >/dev/null 2>&1; then
		docker run --rm --privileged --entrypoint /bin/sh \
			-v "$PROVISION_IMG:/img" \
			alpine:3.20 -c '
				set -e
				apk add --no-cache e2fsprogs >/dev/null
				mkfs.ext4 -F -L provision /img >/dev/null
			' || die "failed to mkfs provision.img"
	else
		if command -v mkfs.ext4 >/dev/null 2>&1; then
			mkfs.ext4 -F -L provision "$PROVISION_IMG" >/dev/null \
				|| die "failed to mkfs provision.img"
		else
			die "need docker or host mkfs.ext4 to create provision.img"
		fi
	fi
else
	log "reusing existing $PROVISION_IMG (per-developer identity/tunables; FORCE=1 to recreate)"
fi

log "growing emulator rootfs → $EMU_ROOTFS_SIZE (device artifact stays $(wc -c <"$ROOTFS" | tr -d '[:space:]') bytes)"
bash "$ROOT/scripts/expand-ext4-image.sh" "$OUT/rootfs.img" "$EMU_ROOTFS_SIZE"

# Same OS image ships an empty /etc/machine-id (first boot on device). On the
# sim/virt motherboard, systemd's random machine-id path can stall without a
# platform RNG; seed a stable id into the *emulator copy only*.
if command -v docker >/dev/null 2>&1; then
	log "seeding emulator machine-id (emulator rootfs copy only)"
	docker run --rm --privileged --entrypoint /bin/sh \
		-v "$OUT/rootfs.img:/img" \
		alpine:3.20 -c '
			set -e
			apk add --no-cache e2fsprogs >/dev/null
			mkdir -p /mnt && mount -o loop /img /mnt
			if [ ! -s /mnt/etc/machine-id ]; then
				dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d " \n" > /mnt/etc/machine-id
				echo >> /mnt/etc/machine-id
				chmod 444 /mnt/etc/machine-id
			fi
			umount /mnt
		' || warn "machine-id seed skipped (docker mount failed)"
fi

{
	echo "sku=emulator-sim-virt"
	echo "oem_id=sim_virt"
	echo "board_id=sim"
	echo "screen_id=virt"
	echo "image=$OUT/Image"
	echo "rootfs=$OUT/rootfs.img"
	echo "oem_img=$OUT/oem.img"
	echo "provision_img=$OUT/provision.img"
	echo "rootfs_size=$EMU_ROOTFS_SIZE"
	echo "contract=same-os-artifacts"
	echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "git=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >"$OUT/manifest.txt"

cp -f "$ROOT/docs/p32-emulator.md" "$OUT/p32-emulator.md" 2>/dev/null || true

log "done"
cat "$OUT/manifest.txt"
bash "$ROOT/scripts/artifact-size.sh" "$OUT/Image" "$OUT/rootfs.img" "$OUT/oem.img" "$OUT/provision.img"
