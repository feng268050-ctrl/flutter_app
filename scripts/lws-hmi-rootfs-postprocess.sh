#!/usr/bin/env bash
# After build.sh rootfs: strip ynh960 fstab entries Buildroot may skip on incremental builds,
# then refresh rootfs.ext2 so the flash image matches staging target/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

if [[ "$(uname -s)" == Darwin && "${1:-}" != "--inside-docker" ]]; then
	exec bash "$ROOT/scripts/docker-run.sh" bash -lc \
		'bash /work/lws-hmi/scripts/lws-hmi-rootfs-postprocess.sh --inside-docker'
fi

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
TARGET="$(resolve_br_target "$SDK")"
OUT_DIR="$(dirname "$TARGET")"
PROFILE="$(basename "$OUT_DIR")"
STRIP="$SDK/buildroot/board/rockchip/rk3566_rk3568/strip-fstab.sh"

if [[ ! -d "$TARGET" ]]; then
	echo "rootfs-postprocess: skip (missing $TARGET)" >&2
	exit 0
fi

if [[ ! -x "$STRIP" ]]; then
	STRIP="$ROOT/overlay/board/rockchip/rk3566_rk3568/strip-fstab.sh"
fi
[[ -x "$STRIP" ]] || {
	echo "ERROR: strip-fstab.sh missing — run: make apply-overlay" >&2
	exit 1
}

before="$(md5sum "$TARGET/etc/fstab" 2>/dev/null | awk '{print $1}' || true)"
bash "$STRIP" "$TARGET"
after="$(md5sum "$TARGET/etc/fstab" 2>/dev/null | awk '{print $1}' || true)"

if [[ "$before" != "$after" ]]; then
	echo "rootfs-postprocess: fstab changed — repacking rootfs.ext2"
	make -C "$SDK/buildroot" "O=$OUT_DIR" rootfs-ext2
fi

INSTALL="$SDK/buildroot/board/rockchip/rk3566_rk3568/install-systemctl-wrapper.sh"
[[ -x "$INSTALL" ]] || INSTALL="$ROOT/overlay/board/rockchip/rk3566_rk3568/install-systemctl-wrapper.sh"
[[ -x "$INSTALL" ]] || {
	echo "ERROR: install-systemctl-wrapper.sh missing — run: make apply-overlay" >&2
	exit 1
}
export STAGING_DIR="$OUT_DIR/host/aarch64-buildroot-linux-gnu/sysroot"
sh "$INSTALL" "$TARGET" rootfs-postprocess

img="$OUT_DIR/images/rootfs.ext2"
if [[ -f "$img" ]]; then
	echo "rootfs-postprocess: refreshing rootfs.ext2 (sync flash image with target/)"
	make -C "$SDK/buildroot" "O=$OUT_DIR" rootfs-ext2
fi
