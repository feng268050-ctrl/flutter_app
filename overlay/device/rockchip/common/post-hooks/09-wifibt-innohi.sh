#!/bin/bash -e
# AIC module path aliases for ynh960 (ko from kernel build → /vendor/lib/modules).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

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

install -d "$TARGET_DIR/etc"
cat >"$TARGET_DIR/etc/wifibt-chips.txt" <<'EOF'
# ynh960 / Innohi AIC8800 family (multi-ko; use wifibt-bringup.sh, not single-module init)
AIC	AIC8800	c8a1:0082	aic8800_fdrv.ko
AIC	AIC8800D80	c8a1:0082	aic8800_fdrv.ko
AIC	AIC8800DC	c8a1:c08d	aic8800_fdrv.ko
EOF
echo "post-wifibt: installed /etc/wifibt-chips.txt"
