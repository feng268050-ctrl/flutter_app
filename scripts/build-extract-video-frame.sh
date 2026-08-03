#!/usr/bin/env bash
# Cross-compile extract-video-frame → prebuilt/ + rootfs-overlay libexec.
# Links against Buildroot staging GStreamer (same tip as product rootfs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

SRC="$ROOT/native/extract_video_frame/extract_video_frame.c"
OUT_DIR="$ROOT/prebuilt/extract_video_frame/aarch64"
OUT_BIN="$OUT_DIR/extract-video-frame"
OVERLAY_BIN="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/usr/libexec/hmi/extract-video-frame"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
FORCE="${FORCE:-0}"
STAMP_VER="gst-mppjpeg-1"

sync_overlay() {
	if [[ -x "$OUT_BIN" ]]; then
		mkdir -p "$(dirname "$OVERLAY_BIN")"
		install -m 0755 "$OUT_BIN" "$OVERLAY_BIN"
		echo "build-extract-video-frame: synced → $OVERLAY_BIN"
	fi
}

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

do_build() {
	local cc="$1"
	local sdk="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
	local staging pc_cflags pc_libs
	staging="$(resolve_br_output_dir "$sdk")/staging"
	[[ -f "$staging/usr/lib/pkgconfig/gstreamer-1.0.pc" ]] || {
		echo "ERROR: missing $staging/usr/lib/pkgconfig/gstreamer-1.0.pc" >&2
		echo "  Run: make build-gstreamer (restores staging .pc if needed)" >&2
		exit 1
	}
	[[ -f "$SRC" ]] || {
		echo "ERROR: missing $SRC" >&2
		exit 1
	}

	export PKG_CONFIG_SYSROOT_DIR="$staging"
	export PKG_CONFIG_LIBDIR="$staging/usr/lib/pkgconfig"
	pc_cflags="$(pkg-config --cflags gstreamer-1.0 gstreamer-app-1.0)"
	pc_libs="$(pkg-config --libs gstreamer-1.0 gstreamer-app-1.0)"

	mkdir -p "$OUT_DIR"
	echo "build-extract-video-frame: CC=$cc"
	echo "build-extract-video-frame: staging=$staging"
	# shellcheck disable=SC2086
	"$cc" --sysroot="$staging" -O2 -Wall -Wextra -o "$OUT_BIN" "$SRC" \
		$pc_cflags $pc_libs
	[[ -x "$OUT_BIN" ]] || {
		echo "ERROR: binary missing after build" >&2
		exit 1
	}
	prebuilt_stamp "$OUT_DIR" "$STAMP_VER"
	sync_overlay
	bash "$ROOT/scripts/sync-prebuilt-manifest.sh" 2>/dev/null || true
	file "$OUT_BIN" || true
	echo "build-extract-video-frame: done → $OUT_BIN"
}

if prebuilt_ready "$OUT_DIR" && [[ -x "$OUT_BIN" && -x "$OVERLAY_BIN" ]] && [[ "$FORCE" != "1" ]]; then
	echo "build-extract-video-frame: prebuilt ready at $OUT_DIR"
	sync_overlay
	exit 0
fi

if [[ "$FORCE" == "1" ]]; then
	rm -rf "$OUT_DIR"
	rm -f "$OVERLAY_BIN"
fi

# macOS: compile inside builder (linux/amd64) with SDK toolchain + staging.
if [[ "$(uname -s)" == Darwin ]] && [[ "${LWS_HMI_DOCKER:-}" != "1" ]]; then
	exec env LWS_HMI_SKIP_OVERLAY=1 FORCE="$FORCE" BR_OUTPUT="$BR_OUTPUT" \
		bash "$ROOT/scripts/docker-run.sh" \
		bash /work/lws-hmi/scripts/build-extract-video-frame.sh
fi

CC="$(find_cross_gcc)" || {
	echo "ERROR: aarch64 cross gcc not found (SDK prebuilts or Buildroot host)" >&2
	exit 1
}
do_build "$CC"
