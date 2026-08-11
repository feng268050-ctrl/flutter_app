#!/bin/sh
# Bake git-tracked Buildroot LTS pin into rootfs for OS Settings / cyber_hal.
# Source of truth: overlay/buildroot/BUILDROOT_VERSION (single line, e.g. 2025.02.16).
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
PIN_FILE="$HMI_ROOT/overlay/buildroot/BUILDROOT_VERSION"
STAMP_DIR="$TARGET_DIR/usr/share/buildroot"
STAMP="$STAMP_DIR/BUILDROOT_VERSION"

if [ ! -f "$PIN_FILE" ]; then
	echo "sync-buildroot-version: ERROR missing $PIN_FILE" >&2
	exit 1
fi

VER="$(tr -d '[:space:]' <"$PIN_FILE")"
if [ -z "$VER" ]; then
	echo "sync-buildroot-version: ERROR empty $PIN_FILE" >&2
	exit 1
fi

mkdir -p "$STAMP_DIR"
printf '%s\n' "$VER" >"$STAMP"
# Prefer /usr/share stamp; drop legacy probe paths if leftover.
rm -f \
	"$TARGET_DIR/etc/buildroot-version" \
	"$TARGET_DIR/etc/buildroot/BUILDROOT_VERSION"

echo "sync-buildroot-version: $STAMP = $VER"
