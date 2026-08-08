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

grep -q 'PARTLABEL=rootfs_a' "$ROOT_DTSI" \
	|| die "$ROOT_DTSI does not select rootfs_a"

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

build_inventory_dtbs() {
	# Primary board DTB is built by ./build.sh kernel; build any extras.
	local boards=()
	local line b dtb_dir kdir
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
		[[ -z "$line" ]] && continue
		boards+=("$line")
	done <"$INVENTORY"

	dtb_dir=""
	kdir=""
	for candidate in \
		"$SDK/kernel-6.1" \
		"$SDK/kernel"; do
		if [[ -d "$candidate/arch/arm64/boot/dts/rockchip" ]]; then
			kdir="$candidate"
			dtb_dir="$candidate/arch/arm64/boot/dts/rockchip"
			break
		fi
	done
	[[ -n "$dtb_dir" ]] || die "kernel DTB dir missing"

	local default="${FIT_DEFAULT_BOARD:-${boards[0]}}"
	for b in "${boards[@]}"; do
		[[ "$b" == "$default" ]] && continue
		if [[ ! -r "$dtb_dir/${b}.dtb" ]]; then
			echo "=== build extra DTB: ${b}.dtb ==="
			(
				cd "$kdir"
				# Rockchip out-of-tree style: reuse existing .config via make
				make ARCH=arm64 "${b}.dtb" || \
					make ARCH=arm64 "rockchip/${b}.dtb" || \
					die "failed to build ${b}.dtb — is DTS installed?"
			)
		fi
		[[ -r "$dtb_dir/${b}.dtb" ]] || die "missing ${dtb_dir}/${b}.dtb"
	done
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
build_inventory_dtbs
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
build_inventory_dtbs
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
