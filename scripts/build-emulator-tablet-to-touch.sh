#!/usr/bin/env bash
# Cross-compile emulator-tablet-to-touch → prebuilt/ + rootfs overlay libexec.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

SRC="$ROOT/native/emulator_tablet_to_touch/emulator-tablet-to-touch.c"
OUT_DIR="$ROOT/prebuilt/emulator_tablet_to_touch/aarch64"
OUT_BIN="$OUT_DIR/emulator-tablet-to-touch"
OVERLAY_BIN="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/display/emulator-tablet-to-touch"
STAMP_VER="2"
FORCE="${FORCE:-0}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$SRC" ]] || die "missing $SRC"

find_cross_gcc() {
	local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
	local cand br
	for cand in \
		"$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc" \
		"$sdk/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64-aarch64-linux-gnu/bin/aarch64-linux-gnu-gcc"
	do
		if [[ -x "$cand" ]]; then
			echo "$cand"
			return 0
		fi
	done
	br="$(resolve_br_output_dir "$sdk" 2>/dev/null || true)"
	if [[ -n "$br" && -d "$br/host/bin" ]]; then
		for cand in "$br/host/bin/"*-linux-gnu-gcc "$br/host/bin/"*-linux-gcc; do
			[[ -x "$cand" ]] || continue
			echo "$cand"
			return 0
		done
	fi
	return 1
}

sync_overlay() {
	[[ -x "$OUT_BIN" ]] || return 0
	mkdir -p "$(dirname "$OVERLAY_BIN")"
	install -m 0755 "$OUT_BIN" "$OVERLAY_BIN"
	echo "build-emulator-tablet-to-touch: synced → $OVERLAY_BIN"
}

do_build() {
	local cc="$1"
	mkdir -p "$OUT_DIR"
	echo "build-emulator-tablet-to-touch: $cc (static) → $OUT_BIN"
	"$cc" -O2 -Wall -Wextra -static -o "$OUT_BIN" "$SRC"
	prebuilt_stamp "$OUT_DIR" "$STAMP_VER"
	sync_overlay
	bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
	file "$OUT_BIN" || true
}

if prebuilt_ready "$OUT_DIR" && [[ -x "$OUT_BIN" && -x "$OVERLAY_BIN" ]] && [[ "$FORCE" != "1" ]]; then
	echo "build-emulator-tablet-to-touch: prebuilt ready at $OUT_DIR"
	sync_overlay
	exit 0
fi

if [[ "$FORCE" == "1" ]]; then
	rm -rf "$OUT_DIR"
	rm -f "$OVERLAY_BIN"
fi

if [[ "$(uname -s)" == Darwin ]] && [[ "${LWS_HMI_DOCKER:-}" != "1" ]]; then
	exec env LWS_HMI_SKIP_OVERLAY=1 FORCE="$FORCE" \
		bash "$ROOT/scripts/docker-run.sh" \
		bash /work/lws-hmi/scripts/build-emulator-tablet-to-touch.sh
fi

CC="$(find_cross_gcc)" || die "aarch64 cross gcc not found (SDK prebuilts or make build-rootfs)"
do_build "$CC"
