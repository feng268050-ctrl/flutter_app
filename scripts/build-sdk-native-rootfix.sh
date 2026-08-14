#!/usr/bin/env bash
# Rebuild SDK-native ynh960 kernel with root=/dev/mmcblk0p6 (legacy MaskROM path).
# Requires: make apply-overlay first (board DTS synced from overlay/kernel/rockchip/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
SIZE_HELPER="$ROOT/scripts/artifact-size.sh"
DTSI="$SDK/kernel/arch/arm64/boot/dts/rockchip/customer_board_ynh960.dtsi"
MARKER='lws-hmi: sdk-native root=mmcblk0p6'

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -d "$SDK" ]] || die "SDK missing"
[[ -f "$DTSI" ]] || die "missing $DTSI — run make apply-overlay first"

bash "$ROOT/scripts/prepare-sdk-native.sh"

if ! grep -q "$MARKER" "$DTSI"; then
  cat >>"$DTSI" <<'EOF'

/* lws-hmi: sdk-native root=mmcblk0p6 — upgrade_tool often skips GPT PARTUUID on rootfs */
&chosen {
	bootargs = "earlycon=uart8250,mmio32,0xfe660000 console=ttyFIQ0 root=/dev/mmcblk0p6 rw rootfstype=ext4 rootwait loglevel=4";
};
EOF
fi

cd "$SDK"
./build.sh kernel
./build.sh updateimg

mkdir -p "$ROOT/output/firmware"
cp -fL "$SDK/output/update/Image/update.img" "$ROOT/output/firmware/update.img" 2>/dev/null \
  || cp -f "$SDK/output/firmware/update.img" "$ROOT/output/firmware/update.img"

echo ""
echo "=== sdk-native rootfix update.img ready ==="
bash "$SIZE_HELPER" "$ROOT/output/firmware/update.img"
echo "MaskROM: make flash"
