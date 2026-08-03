#!/bin/bash -e
# Install Innohi rk_wifi_init + AIC module path aliases for lws_hmi (MainServer path skipped).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

SDK_DIR="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
if [[ -z "$SDK_DIR" ]]; then
	SDK_DIR="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
fi

INNOHI_BIN="$SDK_DIR/innohi/rootfs/usr/bin"

if [[ -x "$INNOHI_BIN/rk_wifi_init" ]]; then
	install -m 0755 "$INNOHI_BIN/rk_wifi_init" "$TARGET_DIR/usr/bin/rk_wifi_init"
	echo "post-wifibt: installed /usr/bin/rk_wifi_init"
else
	echo "post-wifibt: rk_wifi_init missing under $INNOHI_BIN (optional)"
fi

# Innohi tooling expects /system/lib/modules; post-wifibt deposits .ko under vendor/.
# Combo firmware comes from the OEM radio pack at runtime (not copied here).
install -d "$TARGET_DIR/vendor/lib/modules"
install -d "$TARGET_DIR/vendor/etc/firmware"
install -d "$TARGET_DIR/system/lib"
if [[ ! -e "$TARGET_DIR/system/lib/modules" ]]; then
	ln -sfn /vendor/lib/modules "$TARGET_DIR/system/lib/modules"
	echo "post-wifibt: linked /system/lib/modules → /vendor/lib/modules"
fi
install -d "$TARGET_DIR/system/etc"
if [[ ! -e "$TARGET_DIR/system/etc/firmware" ]]; then
	ln -sfn /vendor/etc/firmware "$TARGET_DIR/system/etc/firmware"
	echo "post-wifibt: linked /system/etc/firmware → /vendor/etc/firmware"
fi

# Rockchip wifibt-util does not list AIC IDs; document for bringup/debug.
install -d "$TARGET_DIR/etc"
cat >"$TARGET_DIR/etc/wifibt-chips.txt" <<'EOF'
# ynh960 / Innohi AIC8800 family (multi-ko; use wifibt-bringup.sh, not single-module init)
AIC	AIC8800	c8a1:0082	aic8800_fdrv.ko
AIC	AIC8800D80	c8a1:0082	aic8800_fdrv.ko
AIC	AIC8800DC	c8a1:c08d	aic8800_fdrv.ko
EOF
echo "post-wifibt: installed /etc/wifibt-chips.txt"
