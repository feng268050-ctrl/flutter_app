#!/usr/bin/env bash
# Prepare Buildroot output for one exclusive HMI stack (no rootfs.img pack).
#
# Does: check-prebuilt → apply-overlay → ensure-mali-variant (+ embedder pkgs).
# Shared packages already built in output/ are reused; only Mali / embedder
# flip when the stack stamp or target binaries differ.
#
# Usage:
#   bash scripts/prepare-rootfs-stack.sh weston       # default product stack
#   bash scripts/prepare-rootfs-stack.sh flutter-pi   # alternate
#   FORCE=1 bash scripts/prepare-rootfs-stack.sh weston
#
# Then pack:
#   make build-rootfs              # calls prepare weston, then ./build.sh rootfs
#   make build-rootfs-flutter-pi
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK="${1:?usage: prepare-rootfs-stack.sh <weston|flutter-pi>}"

case "$STACK" in
weston | wayland-gbm)
	STACK=weston
	export LWS_HMI_WESTON=1
	MALI=wayland-gbm
	;;
flutter-pi | pi | gbm)
	STACK=flutter-pi
	export LWS_HMI_WESTON=0
	MALI=gbm
	;;
*)
	echo "ERROR: stack must be weston or flutter-pi (got: $STACK)" >&2
	exit 2
	;;
esac

echo "prepare-rootfs-stack: ${STACK} (LWS_HMI_WESTON=${LWS_HMI_WESTON} mali=${MALI})"

bash "$ROOT/scripts/check-prebuilt.sh"
bash "$ROOT/scripts/apply-overlay.sh"
bash "$ROOT/scripts/ensure-mali-variant.sh" "$MALI"

if [[ "$STACK" = flutter-pi ]]; then
	echo "prepare-rootfs-stack: ${STACK} ready — next: make build-rootfs-flutter-pi"
else
	echo "prepare-rootfs-stack: ${STACK} ready — next: make build-rootfs"
fi
