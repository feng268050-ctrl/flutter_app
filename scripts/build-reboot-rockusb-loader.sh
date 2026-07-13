#!/usr/bin/env bash
# Build reboot-loader with the same Buildroot host toolchain as rootfs.
# Intended to run from lws-hmi-post-fakeroot.sh during make build-rootfs (TARGET_DIR=.../target).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

SRC="$ROOT/tools/reboot-rockusb-loader/reboot-rockusb-loader.c"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -f "$SRC" ]] || die "missing source: $SRC"

resolve_br_out() {
	if [[ -n "${O:-}" && -d "${O}/host/bin" ]]; then
		echo "$O"
		return 0
	fi
	local dir="${1:-}"
	if [[ -n "$dir" ]]; then
		dir="$(cd "$dir" && pwd)"
		while [[ "$dir" != "/" ]]; do
			if [[ -d "$dir/host/bin" ]]; then
				echo "$dir"
				return 0
			fi
			dir="$(dirname "$dir")"
		done
	fi
	local sdk="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print)}"
	resolve_br_output_dir "$sdk"
}

TARGET_DIR="${1:-}"
if [[ -n "$TARGET_DIR" ]]; then
	OUT="$TARGET_DIR/usr/lib/lws-hmi/reboot-loader"
	BR_OUT="$(resolve_br_out "$TARGET_DIR")"
else
	BR_OUT="$(resolve_br_out)"
	TARGET_DIR="$BR_OUT/target"
	OUT="$TARGET_DIR/usr/lib/lws-hmi/reboot-loader"
fi

HOST_BIN="$BR_OUT/host/bin"
[[ -d "$HOST_BIN" ]] || die "Buildroot host bin missing: $HOST_BIN (run: make build-rootfs)"

GCC=""
for g in "$HOST_BIN/"*-linux-gnu-gcc "$HOST_BIN/"*-linux-gcc; do
	[[ -x "$g" ]] || continue
	GCC="$g"
	break
done
[[ -n "$GCC" ]] || die "cross gcc not found under $HOST_BIN"

SYSROOT="$BR_OUT/host/aarch64-buildroot-linux-gnu/sysroot"
[[ -d "$SYSROOT" ]] || SYSROOT="$BR_OUT/host/aarch64-none-linux-gnu/sysroot"
[[ -d "$SYSROOT" ]] || die "sysroot missing under $BR_OUT/host"

mkdir -p "$(dirname "$OUT")"
rm -f "$TARGET_DIR/usr/lib/lws-hmi/reboot-rockusb-loader"
echo "build-reboot-loader: $GCC (static, sysroot=$SYSROOT) -> $OUT"
"$GCC" --sysroot="$SYSROOT" -O2 -Wall -Wextra -static -o "$OUT" "$SRC"
chmod 0755 "$OUT"
file "$OUT"
