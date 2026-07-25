#!/usr/bin/env bash
# Prepare Buildroot output for the Weston + eLinux HMI stack (no rootfs.img pack).
#
# Does: check-prebuilt → apply-overlay → ensure-mali-variant (+ embedder pkgs).
# Shared packages already built in output/ are reused; only Mali / embedder
# flip when the stack stamp or target binaries differ.
#
# Usage:
#   bash scripts/prepare-rootfs-stack.sh weston
#   FORCE=1 bash scripts/prepare-rootfs-stack.sh weston
#
# Then pack:
#   make build-rootfs
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="${1:-weston}"

case "$STACK" in
weston | wayland-gbm | "" )
	STACK=weston
	export LWS_HMI_WESTON=1
	MALI=wayland-gbm
	;;
*)
	echo "ERROR: only the Weston stack is supported (got: $STACK)" >&2
	echo "  flutter-pi alternate rootfs was removed; use: make prepare-rootfs" >&2
	exit 2
	;;
esac

echo "prepare-rootfs-stack: ${STACK} (LWS_HMI_WESTON=${LWS_HMI_WESTON} mali=${MALI})"

bash "$ROOT/scripts/check-prebuilt.sh"
bash "$ROOT/scripts/apply-overlay.sh"
bash "$ROOT/scripts/ensure-mali-variant.sh" "$MALI"

echo "prepare-rootfs-stack: ${STACK} ready — next: make build-rootfs"
