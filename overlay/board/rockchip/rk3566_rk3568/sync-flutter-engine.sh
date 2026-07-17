#!/bin/sh
# Install Flutter engine + icudtl from lws-hmi prebuilt into system paths only.
# /opt/hmi carries libapp.so + assets; engine updates with rootfs (like rknn runtime).
set -eu

TARGET_DIR="${1:?TARGET_DIR required}"
HMI_ROOT="${LWS_HMI_ROOT:-/work/lws-hmi}"
RUNTIME_MODE="${FLUTTER_ENGINE_RUNTIME_MODE:-release}"

read_ver() {
	if [ -f "$HMI_ROOT/overlay/buildroot/flutter-engine.version" ]; then
		tr -d '[:space:]' <"$HMI_ROOT/overlay/buildroot/flutter-engine.version"
	else
		echo "3.24.4"
	fi
}

VER="$(read_ver)"
PREBUILT_ROOT="$HMI_ROOT/prebuilt/flutter-engine/${VER}/arm64-${RUNTIME_MODE}/target"
ENGINE_SO="$PREBUILT_ROOT/usr/lib/libflutter_engine.so"
ICU_DAT="$PREBUILT_ROOT/usr/share/flutter/${RUNTIME_MODE}/data/icudtl.dat"
ICU_SYSTEM_DIR="$TARGET_DIR/usr/share/flutter/${RUNTIME_MODE}/data"
ICU_LEGACY_LINK="$TARGET_DIR/usr/share/flutter/icudtl.dat"

if [ ! -f "$ENGINE_SO" ]; then
	echo "lws-hmi-sync-flutter-engine: skip (missing $ENGINE_SO)" >&2
	exit 0
fi

install -m 0755 "$ENGINE_SO" "$TARGET_DIR/usr/lib/libflutter_engine.so"
if [ -f "$ICU_DAT" ]; then
	install -D -m 0644 "$ICU_DAT" "$ICU_SYSTEM_DIR/icudtl.dat"
	mkdir -p "$(dirname "$ICU_LEGACY_LINK")"
	ln -sf "${RUNTIME_MODE}/data/icudtl.dat" "$ICU_LEGACY_LINK"
fi

# App bundle must not ship a second engine/icu copy (~40MB); flutter-pi dlopens from /usr/lib.
rm -f \
	"$TARGET_DIR/opt/hmi/lib/libflutter_engine.so" \
	"$TARGET_DIR/opt/hmi/data/icudtl.dat"

prebuilt_sz="$(wc -c <"$ENGINE_SO")"
target_sz="$(wc -c <"$TARGET_DIR/usr/lib/libflutter_engine.so")"
if [ "$prebuilt_sz" != "$target_sz" ]; then
	echo "lws-hmi-sync-flutter-engine: ERROR size mismatch after sync" >&2
	exit 1
fi
echo "lws-hmi-sync-flutter-engine: system engine ${VER} arm64-${RUNTIME_MODE} ($target_sz bytes)"
