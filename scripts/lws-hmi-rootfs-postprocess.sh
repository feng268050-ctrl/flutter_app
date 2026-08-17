#!/usr/bin/env bash
# After build.sh rootfs: strip ynh960 fstab entries Buildroot may skip on incremental
# builds, ensure systemctl wrapper, and repack rootfs.ext2 only when target/ mutated.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

if [[ "$(uname -s)" == Darwin && "${1:-}" != "--inside-docker" ]]; then
	exec bash "$ROOT/scripts/docker-run.sh" bash -lc \
		'bash /work/lws-hmi/scripts/lws-hmi-rootfs-postprocess.sh --inside-docker'
fi

SDK="${SDK_DIR:-$ROOT/linux-sdk}"
# shellcheck source=platform-paths.sh
source "$ROOT/scripts/platform-paths.sh"
platform_paths_init "$ROOT" "$SDK"

TARGET="$(resolve_br_target "$SDK")"
OUT_DIR="$(dirname "$TARGET")"
NEED_REPACK=0

if [[ ! -d "$TARGET" ]]; then
	echo "rootfs-postprocess: skip (missing $TARGET)" >&2
	exit 0
fi

STRIP="$(platform_paths_board_script strip-fstab.sh || true)"
[[ -x "$STRIP" ]] || {
	echo "ERROR: strip-fstab.sh missing — run: make apply-overlay" >&2
	exit 1
}

before="$(md5sum "$TARGET/etc/fstab" 2>/dev/null | awk '{print $1}' || true)"
bash "$STRIP" "$TARGET"
after="$(md5sum "$TARGET/etc/fstab" 2>/dev/null | awk '{print $1}' || true)"

if [[ "$before" != "$after" ]]; then
	echo "rootfs-postprocess: fstab changed — will repack rootfs.ext2"
	NEED_REPACK=1
fi

INSTALL="$(platform_paths_board_script install-systemctl-wrapper.sh || true)"
[[ -x "$INSTALL" ]] || {
	echo "ERROR: install-systemctl-wrapper.sh missing — run: make apply-overlay" >&2
	exit 1
}
export STAGING_DIR="$OUT_DIR/host/aarch64-buildroot-linux-gnu/sysroot"
wrapper_out="$(sh "$INSTALL" "$TARGET" rootfs-postprocess)"
printf '%s\n' "$wrapper_out"
case "$wrapper_out" in
*"already installed"*)
	;;
*)
	echo "rootfs-postprocess: systemctl wrapper changed — will repack rootfs.ext2"
	NEED_REPACK=1
	;;
esac

REFRESH="$(platform_paths_board_script refresh-plan-a-systemd-wants.sh || true)"
if [[ -f "$REFRESH" ]]; then
	sh "$REFRESH" "$TARGET"
	echo "rootfs-postprocess: refreshed Plan A systemd wants (multi-user + sysinit)"
else
	echo "rootfs-postprocess: WARN refresh-plan-a-systemd-wants.sh missing — run make apply-overlay" >&2
fi

if [[ "$NEED_REPACK" -eq 1 ]]; then
	echo "rootfs-postprocess: repacking rootfs.ext2 (target/ mutated after build.sh)"
	make -C "$SDK/buildroot" "O=$OUT_DIR" rootfs-ext2
else
	echo "rootfs-postprocess: skip rootfs-ext2 (fstab + systemctl wrapper unchanged)"
fi
