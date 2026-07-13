#!/bin/sh
# Mode-aware flutter-pi launcher for release and debug payloads.
set -eu

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
MODE=release

read_json_field() {
	file="$1"
	key="$2"
	grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| sed 's/.*"\([^"]*\)"$/\1/' \
		| head -1
}

if [ -f "$MODE_FILE" ]; then
	MODE="$(read_json_field "$MODE_FILE" mode)"
	MODE="${MODE:-release}"
fi

if [ "$MODE" = "debug" ]; then
	VER="$(read_json_field "$MODE_FILE" engine_version)"
	RT="/var/lib/lws-hmi/debug-runtime/${VER}"
	if [ -f "$RT/libflutter_engine.so" ] && [ -f "$RT/icudtl.dat" ]; then
		if [ ! -f "$BUNDLE/data/flutter_assets/kernel_blob.bin" ]; then
			echo "lws-hmi-hmi-launch: missing debug kernel $BUNDLE/data/flutter_assets/kernel_blob.bin" >&2
			exit 1
		fi
		export FLUTTER_EMBEDDER_ICU_DATA_PATH="$RT/icudtl.dat"
		exec env LD_LIBRARY_PATH="$RT" /usr/bin/flutter-pi -o landscape_left "$BUNDLE"
	fi
	echo "lws-hmi-hmi-launch: debug runtime missing at $RT; falling back to release engine" >&2
	MODE=release
fi

if [ ! -f "$BUNDLE/lib/libapp.so" ]; then
	echo "lws-hmi-hmi-launch: missing release AOT $BUNDLE/lib/libapp.so" >&2
	exit 1
fi

# Release path must match pre-P1.5 hmi.service: no LD_LIBRARY_PATH / ICU overrides.
exec /usr/bin/flutter-pi --release -o landscape_left "$BUNDLE"
