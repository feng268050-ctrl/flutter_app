#!/usr/bin/env bash
# Cross-compile libhmi_capture.so → prebuilt/ + rootfs-overlay usr/lib/.
# Links against Buildroot staging GStreamer (same tip as product rootfs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

SRC_DIR="$ROOT/native/hmi_capture"
SRC="$SRC_DIR/hmi_capture.c"
HDR="$SRC_DIR/hmi_capture.h"
OUT_DIR="$ROOT/prebuilt/hmi_capture/aarch64"
OUT_SO="$OUT_DIR/libhmi_capture.so"
OVERLAY_SO="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/lib/libhmi_capture.so"
OVERLAY_HDR="$ROOT/overlay/board/rockchip/common/rootfs-overlay/usr/include/hmi_capture.h"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
FORCE="${FORCE:-0}"
STAMP_VER="present-hook-mpp-1"

sync_overlay() {
	if [[ -f "$OUT_SO" ]]; then
		mkdir -p "$(dirname "$OVERLAY_SO")" "$(dirname "$OVERLAY_HDR")"
		install -m 0755 "$OUT_SO" "$OVERLAY_SO"
		install -m 0644 "$HDR" "$OVERLAY_HDR"
		echo "build-hmi-capture: synced → $OVERLAY_SO"
	fi
}

find_cross_gcc() {
	local sdk="${SDK_DIR:-$ROOT/linux-sdk}"
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

do_build() {
	local cc="$1"
	local sdk="${SDK_DIR:-$ROOT/linux-sdk}"
	local staging pc_cflags pc_libs
	staging="$(resolve_br_output_dir "$sdk")/staging"
	[[ -f "$staging/usr/lib/pkgconfig/gstreamer-1.0.pc" ]] || {
		echo "ERROR: missing $staging/usr/lib/pkgconfig/gstreamer-1.0.pc" >&2
		echo "  Run: make build-gstreamer (restores staging .pc if needed)" >&2
		exit 1
	}
	[[ -f "$SRC" && -f "$HDR" ]] || {
		echo "ERROR: missing $SRC or $HDR" >&2
		exit 1
	}

	export PKG_CONFIG_SYSROOT_DIR="$staging"
	export PKG_CONFIG_LIBDIR="$staging/usr/lib/pkgconfig"
	pc_cflags="$(pkg-config --cflags gstreamer-1.0 gstreamer-app-1.0)"
	pc_libs="$(pkg-config --libs gstreamer-1.0 gstreamer-app-1.0)"

	mkdir -p "$OUT_DIR"
	echo "build-hmi-capture: CC=$cc"
	echo "build-hmi-capture: staging=$staging"
	# shellcheck disable=SC2086
	"$cc" --sysroot="$staging" -O2 -Wall -Wextra -fPIC -shared \
		-o "$OUT_SO" "$SRC" \
		-I"$SRC_DIR" $pc_cflags $pc_libs -lpthread -ldl
	[[ -f "$OUT_SO" ]] || {
		echo "ERROR: shared library missing after build" >&2
		exit 1
	}
	prebuilt_stamp "$OUT_DIR" "$STAMP_VER"
	sync_overlay
	bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
	file "$OUT_SO" || true
	echo "build-hmi-capture: done → $OUT_SO"
}

if prebuilt_ready "$OUT_DIR" && [[ -f "$OUT_SO" && -f "$OVERLAY_SO" ]] && [[ "$FORCE" != "1" ]]; then
	echo "build-hmi-capture: prebuilt ready at $OUT_DIR"
	sync_overlay
	exit 0
fi

if [[ "$FORCE" == "1" ]]; then
	rm -rf "$OUT_DIR"
	rm -f "$OVERLAY_SO" "$OVERLAY_HDR"
fi

if [[ "$(uname -s)" == Darwin ]] && [[ "${DOCKER:-}" != "1" ]]; then
	exec env SKIP_OVERLAY=1 FORCE="$FORCE" BR_OUTPUT="$BR_OUTPUT" \
		bash "$ROOT/scripts/docker-run.sh" \
		bash /work/lws-hmi/scripts/build-hmi-capture.sh
fi

CC="$(find_cross_gcc)" || {
	echo "ERROR: aarch64 cross gcc not found (SDK prebuilts or Buildroot host)" >&2
	exit 1
}
do_build "$CC"
