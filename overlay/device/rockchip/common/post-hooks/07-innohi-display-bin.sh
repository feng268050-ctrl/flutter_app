#!/bin/bash -e

# Install Innohi ynh960 display helpers (MountAll, ParamUpdate, MainServer).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

SDK_DIR="${LWS_HMI_SDK_DIR:-${RK_SDK_DIR:-}}"
if [[ -z "$SDK_DIR" ]]; then
	SDK_DIR="$(cd "$(dirname "$TARGET_DIR")/../../../.." && pwd)"
fi

INNOHI_BIN="$SDK_DIR/innohi_board/rootfs/usr/bin"
if [[ ! -d "$INNOHI_BIN" ]]; then
	echo "lws-hmi-innohi: skip (missing $INNOHI_BIN — run make apply-overlay)"
	exit 0
fi

for bin in MountAll ParamUpdate MainServer; do
	if [[ ! -x "$INNOHI_BIN/$bin" ]]; then
		echo "lws-hmi-innohi: skip missing $INNOHI_BIN/$bin"
		continue
	fi
	install -m 0755 "$INNOHI_BIN/$bin" "$TARGET_DIR/usr/bin/$bin"
	echo "lws-hmi-innohi: installed /usr/bin/$bin"
done

LWS_HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
DISPLAY_INIT="$LWS_HMI_ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/usr/lib/lws-hmi/ynh960-display-init.sh"
if [[ -f "$DISPLAY_INIT" ]]; then
	install -d "$TARGET_DIR/usr/lib/lws-hmi"
	install -m 0755 "$DISPLAY_INIT" "$TARGET_DIR/usr/lib/lws-hmi/ynh960-display-init.sh"
	echo "lws-hmi-innohi: installed /usr/lib/lws-hmi/ynh960-display-init.sh"
fi

install -d "$TARGET_DIR/system/bin"
for bin in MountAll ParamUpdate MainServer; do
	[[ -x "$TARGET_DIR/usr/bin/$bin" ]] || continue
	ln -sf "/usr/bin/$bin" "$TARGET_DIR/system/bin/$bin"
	echo "lws-hmi-innohi: /system/bin/$bin -> /usr/bin/$bin"
done

INNOHI_UDEV="$SDK_DIR/innohi_board/rootfs/usr/lib/udev/rules.d/61-partition-init.rules"
if [[ -f "$INNOHI_UDEV" ]]; then
	install -d "$TARGET_DIR/usr/lib/udev/rules.d"
	install -m 0644 "$INNOHI_UDEV" "$TARGET_DIR/usr/lib/udev/rules.d/61-partition-init.rules"
	echo "lws-hmi-innohi: installed udev 61-partition-init.rules (by-name links)"
fi
