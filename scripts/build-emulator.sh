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

log "growing emulator rootfs → $EMU_ROOTFS_SIZE (device artifact stays $(wc -c <"$ROOTFS" | tr -d '[:space:]') bytes)"
bash "$ROOT/scripts/expand-ext4-image.sh" "$OUT/rootfs.img" "$EMU_ROOTFS_SIZE"

{
	echo "sku=emulator-sim-virt"
	echo "oem_id=sim_virt"
	echo "board_id=sim"
	echo "screen_id=virt"
	echo "image=$OUT/Image"
	echo "rootfs=$OUT/rootfs.img"
	echo "oem_img=$OUT/oem.img"
	echo "rootfs_size=$EMU_ROOTFS_SIZE"
	echo "contract=same-os-artifacts"
	echo "built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "git=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} >"$OUT/manifest.txt"

cp -f "$ROOT/docs/p32-emulator.md" "$OUT/p32-emulator.md" 2>/dev/null || true

log "done"
cat "$OUT/manifest.txt"
bash "$ROOT/scripts/artifact-size.sh" "$OUT/Image" "$OUT/rootfs.img" "$OUT/oem.img"
