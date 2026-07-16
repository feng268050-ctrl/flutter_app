#!/usr/bin/env bash
# Build two hash-valid FIT images: boot.img → rootfs_a, boot_b.img → rootfs_b.
# Run inside the SDK container (/work/sdk).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-/work/sdk}"
FIRMWARE="$SDK/output/firmware"
ROOT_DTSI=""

die() {
	echo "ERROR: $*" >&2
	exit 1
}

for candidate in \
	"$SDK/kernel-6.1/arch/arm64/boot/dts/rockchip/lws-hmi-ynh960-linux-root.dtsi" \
	"$SDK/kernel/arch/arm64/boot/dts/rockchip/lws-hmi-ynh960-linux-root.dtsi"; do
	if [[ -f "$candidate" ]]; then
		ROOT_DTSI="$candidate"
		break
	fi
done
[[ -n "$ROOT_DTSI" ]] || die "installed lws-hmi root DTSI not found (run make apply-overlay)"

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

echo "=== A/B kernel FIT: build A (rootfs_a) ==="
(
	cd "$SDK"
	./build.sh kernel
)
[[ -r "$FIRMWARE/boot.img" ]] || die "A FIT missing: $FIRMWARE/boot.img"
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
rm -f "$FIRMWARE/boot_b.img"
cp -Lf "$FIRMWARE/boot.img" "$FIRMWARE/boot_b.img"
grep -aFq 'PARTLABEL=rootfs_b' "$FIRMWARE/boot_b.img" \
	|| die "B FIT does not contain root=PARTLABEL=rootfs_b"

restore
trap - EXIT

echo "A/B kernel FITs ready:"
bash "$ROOT/scripts/artifact-size.sh" \
	"$FIRMWARE/boot.img" "$FIRMWARE/boot_b.img"
