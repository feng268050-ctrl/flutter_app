#!/bin/bash -e

# LCD/MIPI tables no longer go to /system/etc (ParamUpdate retired; panel is kernel DT).
# Source of truth: board/lcd_mipi_param.txt → overlay/kernel/rockchip/ynh960-panel-init.dtsi

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

rm -f \
	"$TARGET_DIR/system/etc/960_lcd_param_rk356x.txt" \
	"$TARGET_DIR/system/etc/lcd_mipi_param.txt" \
	"$TARGET_DIR/system/etc/LCD_PARAM_RK356X_V11_0.txt"
echo "post-display: skip /system/etc LCD copy (ParamUpdate retired)"
