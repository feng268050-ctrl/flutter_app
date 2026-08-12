#!/usr/bin/env bash
# Build two hash-valid FIT images: boot.img → rootfs_a, boot_b.img → rootfs_b.
# Multi-conf FIT (W5): inventory boards share one Image; conf name = board_id.
# Run inside the SDK container (/work/sdk).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-/work/sdk}"
FIRMWARE="$SDK/output/firmware"
INVENTORY="${FIT_BOARD_INVENTORY:-$ROOT/board/rk356x-fit-boards.txt}"
ROOT_DTSI=""

die() {
	echo "ERROR: $*" >&2
	exit 1
}

for candidate in \
	"$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip/ynh960-linux-root.dtsi" \
	"$SDK/kernel/arch/arm64/boot/dts/rockchip/ynh960-linux-root.dtsi"; do
	if [[ -f "$candidate" ]]; then
		ROOT_DTSI="$candidate"
		break
	fi
done
[[ -n "$ROOT_DTSI" ]] || die "installed ynh960 root DTSI not found (run make apply-overlay)"

backup="$(mktemp)"
cp -f "$ROOT_DTSI" "$backup"
boot_a_tmp="$FIRMWARE/.boot-a.img"

restore() {
	cp -f "$backup" "$ROOT_DTSI"
	rm -f "$backup"
	if [[ -f "$boot_a_tmp" ]]; then
		rm -f "$FIRMWARE/boot.img"
		cp -f "$boot_a_tmp" "$FIRMWARE/boot.img"
		rm -f "$boot_a_tmp"
	fi
}
trap restore EXIT

# Prefer bootargs assignment — comments also mention rootfs_b.
grep -E 'bootargs[[:space:]]*=[[:space:]]*".*root=PARTLABEL=rootfs_a' "$ROOT_DTSI" >/dev/null \
	|| die "$ROOT_DTSI does not select rootfs_a (bootargs)"

# Ensure multi-conf ITS is generated and installed before kernel pack.
bash "$ROOT/scripts/generate-boot-fit-its.sh" \
	"$INVENTORY" "$ROOT/board/boot-multi.its"
for dest_dir in \
	"$SDK/device/rockchip/.chips/rk3566_rk3568" \
	"$SDK/device/rockchip/rk3566_rk3568"; do
	if [[ -d "$dest_dir" ]]; then
		cp -f "$ROOT/board/boot-multi.its" "$dest_dir/boot-multi.its"
	fi
done

resolve_dtb_dirs() {
	DTB_DIR=""
	KDIR=""
	for candidate in \
		"$SDK/kernel-6.1" \
		"$SDK/kernel"; do
		if [[ -d "$candidate/arch/arm64/boot/dts/rockchip" ]]; then
			KDIR="$candidate"
			DTB_DIR="$candidate/arch/arm64/boot/dts/rockchip"
			return 0
		fi
	done
	die "kernel DTB dir missing"
}

read_inventory_boards() {
	local line
	BOARDS=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[[ -z "$line" ]] && continue
		BOARDS+=("$line")
	done <"$INVENTORY"
	[[ ${#BOARDS[@]} -gt 0 ]] || die "empty FIT board inventory: $INVENTORY"
}

# Rockchip Make often misses .dtsi → .dtb deps. After switching
# root=PARTLABEL=rootfs_{a|b} we must force-rebuild every inventory DTB or the
# multi-conf FIT keeps the previous letter's bootargs (B FIT verify fails).
# $1 = expected letter: rootfs_a | rootfs_b (do not grep the DTSI — comments
# mention both letters).
force_rebuild_inventory_dtbs() {
	local expect="${1:?usage: force_rebuild_inventory_dtbs rootfs_a|rootfs_b}"
	local b
	case "$expect" in
	rootfs_a | rootfs_b) ;;
	*) die "force_rebuild_inventory_dtbs: bad letter '$expect'" ;;
	esac
	resolve_dtb_dirs
	read_inventory_boards
	# Nudge Make even when timestamp granularity is coarse (Docker volumes).
	touch "$ROOT_DTSI"
	for b in "${BOARDS[@]}"; do
		rm -f "$DTB_DIR/${b}.dtb"
		echo "=== force rebuild DTB: ${b}.dtb (expect PARTLABEL=${expect}) ==="
		(
			cd "$KDIR"
			make ARCH=arm64 "${b}.dtb" || \
				make ARCH=arm64 "rockchip/${b}.dtb" || \
				die "failed to build ${b}.dtb — is DTS installed?"
		)
		[[ -r "$DTB_DIR/${b}.dtb" ]] || die "missing ${DTB_DIR}/${b}.dtb"
		grep -aFq "PARTLABEL=${expect}" "$DTB_DIR/${b}.dtb" \
			|| die "${b}.dtb missing PARTLABEL=${expect} after rebuild"
	done
}

build_inventory_dtbs() {
	die "internal: call force_rebuild_inventory_dtbs with rootfs_a|rootfs_b"
}

repack_multi_fit() {
	local target="$1"
	LWS_HMI_SDK_DIR="$SDK" bash "$ROOT/scripts/pack-boot-fit-multi.sh" "$target"
	bash "$ROOT/scripts/verify-boot-fit.sh" "$(dirname "$target")" "$(basename "$target")"
}

echo "=== A/B kernel FIT: build A (rootfs_a) ==="
(
	cd "$SDK"
	./build.sh kernel
)
[[ -r "$FIRMWARE/boot.img" ]] || die "A FIT missing: $FIRMWARE/boot.img"
force_rebuild_inventory_dtbs rootfs_a
repack_multi_fit "$FIRMWARE/boot.img"
cp -Lf "$FIRMWARE/boot.img" "$boot_a_tmp"
grep -aFq 'PARTLABEL=rootfs_a' "$boot_a_tmp" \
	|| die "A FIT does not contain root=PARTLABEL=rootfs_a"

echo "=== A/B kernel FIT: build B (rootfs_b) ==="
sed -i 's/PARTLABEL=rootfs_a/PARTLABEL=rootfs_b/g' "$ROOT_DTSI"
(
	cd "$SDK"
	./build.sh kernel
)
[[ -r "$FIRMWARE/boot.img" ]] || die "B FIT missing: $FIRMWARE/boot.img"
force_rebuild_inventory_dtbs rootfs_b
repack_multi_fit "$FIRMWARE/boot.img"
rm -f "$FIRMWARE/boot_b.img"
cp -Lf "$FIRMWARE/boot.img" "$FIRMWARE/boot_b.img"
grep -aFq 'PARTLABEL=rootfs_b' "$FIRMWARE/boot_b.img" \
	|| die "B FIT does not contain root=PARTLABEL=rootfs_b"

restore
trap - EXIT

# Publish bare Image for P3.2 emulator (same binary packed into FIT).
# Emulator MUST NOT require a product FIT conf (no conf-sim).
IMAGE_SRC=""
for candidate in \
	"$SDK/kernel-6.1/arch/arm64/boot/Image" \
	"$SDK/kernel/arch/arm64/boot/Image"; do
	if [[ -r "$candidate" ]]; then
		IMAGE_SRC="$candidate"
		break
	fi
done
if [[ -n "$IMAGE_SRC" ]]; then
	mkdir -p "$FIRMWARE"
	rm -f "$FIRMWARE/Image"
	cp -Lf "$IMAGE_SRC" "$FIRMWARE/Image"
	echo "emulator kernel Image: $FIRMWARE/Image"
	bash "$ROOT/scripts/artifact-size.sh" "$FIRMWARE/Image" || true
else
	echo "WARNING: bare Image not found under kernel*/arch/arm64/boot — emulator publish skipped" >&2
fi

echo "A/B multi-conf kernel FITs ready:"
bash "$ROOT/scripts/artifact-size.sh" \
	"$FIRMWARE/boot.img" "$FIRMWARE/boot_b.img"
bash "$ROOT/scripts/verify-boot-fit.sh" "$FIRMWARE" boot.img
bash "$ROOT/scripts/verify-boot-fit.sh" "$FIRMWARE" boot_b.img
