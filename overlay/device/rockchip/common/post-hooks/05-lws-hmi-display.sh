#!/bin/bash -e

# Install ynh960 LCD + MIPI init tables into Buildroot rootfs.
# ParamUpdate (Innohi) reads /system/etc/{960_lcd_param_rk356x.txt,lcd_mipi_param.txt}
# and may also honor the legacy LCD_PARAM_RK356X_V11_0.txt name.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
BOARD_DIR="$LWS_HMI_ROOT/board"
if [[ ! -d "$BOARD_DIR" && -d "$(dirname "$0")/../../../../../../../lws-hmi/board" ]]; then
	# Fallback when building outside Docker (host path next to SDK).
	BOARD_DIR="$(realpath "$(dirname "$0")/../../../../../../..")/board"
fi

if [[ ! -f "$BOARD_DIR/960_lcd_param_rk356x.txt" ]]; then
	echo "lws-hmi-display: skip (missing $BOARD_DIR/960_lcd_param_rk356x.txt)"
	exit 0
fi

DEST="$TARGET_DIR/system/etc"
mkdir -p "$DEST"

install -m 0644 "$BOARD_DIR/960_lcd_param_rk356x.txt" \
	"$DEST/960_lcd_param_rk356x.txt"
install -m 0644 "$BOARD_DIR/960_lcd_param_rk356x.txt" \
	"$DEST/LCD_PARAM_RK356X_V11_0.txt"

if [[ -f "$BOARD_DIR/lcd_mipi_param.txt" ]]; then
	install -m 0644 "$BOARD_DIR/lcd_mipi_param.txt" \
		"$DEST/lcd_mipi_param.txt"
fi

echo "lws-hmi-display: installed LCD/MIPI params under $DEST"
