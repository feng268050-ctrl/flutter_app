#!/bin/bash -e

# Run after Rockchip 30-fstab.sh (which re-adds PARTLABEL=userdata).

source "${RK_POST_HELPER:-$(dirname "$(realpath "$0")")/post-helper}"

[ "$POST_OS" = buildroot ] || exit 0

sdk_dir="${SDK_DIR:-${RK_SDK_DIR:-}}"
if [ -z "$sdk_dir" ]; then
	sdk_dir="$(cd "$(dirname "$0")/../../../.." && pwd)"
fi
SCRIPT="$sdk_dir/buildroot/board/rockchip/rk3566_rk3568/strip-fstab.sh"
if [ ! -f "$SCRIPT" ]; then
	SCRIPT="${DOCKER_ROOT:-/work/lws-hmi}/overlay/board/rockchip/rk3566_rk3568/strip-fstab.sh"
fi
if [ ! -f "$SCRIPT" ]; then
	echo "post-strip-fstab: skip (missing strip-fstab.sh — run make apply-overlay)"
	exit 0
fi

bash "$SCRIPT" "$TARGET_DIR"
