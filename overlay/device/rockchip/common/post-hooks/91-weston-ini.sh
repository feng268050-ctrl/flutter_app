#!/bin/bash -e
# After Rockchip 90-overlay installs common/overlays/10-weston (stock weston.ini
# with no panel transform), replace with ynh960 landscape config.

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0
[ -x "$TARGET_DIR/usr/bin/weston" ] || exit 0

src="${LWS_HMI_ROOT:-/work/lws-hmi}/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/etc/xdg/weston/weston.ini"
if [ ! -f "$src" ]; then
	src="$TARGET_DIR/usr/libexec/hmi/weston.ini"
fi
if [ ! -f "$src" ]; then
	# Fall back to board BR overlay synced into the SDK tree.
	sdk_dir="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
	if [ -n "$sdk_dir" ]; then
		src="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/rootfs-overlay/etc/xdg/weston/weston.ini"
	fi
fi
if [ ! -f "$src" ]; then
	echo "post-weston-ini: skip (no landscape weston.ini source)"
	exit 0
fi

mkdir -p "$TARGET_DIR/etc/xdg/weston"
install -m 0644 "$src" "$TARGET_DIR/etc/xdg/weston/weston.ini"
# Drop-ins must not reintroduce a panel; keep a minimal shell fragment.
mkdir -p "$TARGET_DIR/etc/xdg/weston/weston.ini.d"
printf '%s\n' '[shell]' 'locking=false' 'animation=none' 'startup-animation=none' \
	'panel-position=none' \
	>"$TARGET_DIR/etc/xdg/weston/weston.ini.d/02-desktop.ini"
echo "post-weston-ini: installed landscape weston.ini (transform=rotate-270)"
