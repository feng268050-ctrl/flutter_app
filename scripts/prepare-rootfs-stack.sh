#!/usr/bin/env bash
# Prepare Buildroot output for one exclusive HMI stack (no rootfs.img pack).
#
# Does: check-prebuilt → apply-overlay → ensure-mali-variant (+ embedder pkgs).
# Shared packages already built in output/ are reused; only Mali / embedder
# flip when the stack stamp or target binaries differ.
#
# Usage:
#   bash scripts/prepare-rootfs-stack.sh flutter-pi
#   bash scripts/prepare-rootfs-stack.sh weston
#   FORCE=1 bash scripts/prepare-rootfs-stack.sh weston   # force Mali/embedder rebuild
#
# Then pack:
#   make build-rootfs          # calls prepare flutter-pi, then ./build.sh rootfs
#   make build-rootfs-weston
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="${1:?usage: prepare-rootfs-stack.sh <flutter-pi|weston>}"

case "$STACK" in
flutter-pi | pi | gbm)
	STACK=flutter-pi
	export LWS_HMI_WESTON=0
	MALI=gbm
	;;
weston | wayland-gbm)
	STACK=weston
	export LWS_HMI_WESTON=1
	MALI=wayland-gbm
	;;
*)
	echo "ERROR: stack must be flutter-pi or weston (got: $STACK)" >&2
	exit 2
	;;
esac

echo "prepare-rootfs-stack: ${STACK} (LWS_HMI_WESTON=${LWS_HMI_WESTON} mali=${MALI})"

bash "$ROOT/scripts/check-prebuilt.sh"
bash "$ROOT/scripts/apply-overlay.sh"
bash "$ROOT/scripts/ensure-mali-variant.sh" "$MALI"

echo "prepare-rootfs-stack: ${STACK} ready — next: make build-rootfs$([ "$STACK" = weston ] && echo -weston || true)"
