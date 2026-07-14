#!/bin/sh
# Mode-aware flutter-pi launcher for release and debug payloads.
set -eu

BUNDLE=/opt/hmi
MODE_FILE="$BUNDLE/runtime-mode.json"
MODE=release
ORIENTATION_FILE=/var/lib/lws-hmi/display-orientation

# Default matches ynh960 production (lcd0_rotation=90 → landscape_left).
FLUTTER_PI_ORIENTATION=landscape_left

# RK809 speaker path (ParamUpdate also sets this; re-assert before HMI audio smoke).
if command -v amixer >/dev/null 2>&1; then
	amixer -q sset 'Playback Path' 'RING_SPK_HP' 2>/dev/null || true
fi

read_json_field() {
	file="$1"
	key="$2"
	grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null \
		| sed 's/.*"\([^"]*\)"$/\1/' \
		| head -1
}

if [ -f "$ORIENTATION_FILE" ]; then
	token="$(tr -d '[:space:]' <"$ORIENTATION_FILE" | tr '[:upper:]' '[:lower:]')"
	case "$token" in
	portrait)
		FLUTTER_PI_ORIENTATION=portrait_up
		;;
	landscape|"")
		FLUTTER_PI_ORIENTATION=landscape_left
		;;
	*)
		echo "lws-hmi-hmi-launch: unknown orientation '$token'; using landscape_left" >&2
		FLUTTER_PI_ORIENTATION=landscape_left
		;;
	esac
fi

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
		exec env LD_LIBRARY_PATH="$RT" /usr/bin/flutter-pi -o "$FLUTTER_PI_ORIENTATION" "$BUNDLE"
	fi
	echo "lws-hmi-hmi-launch: debug runtime missing at $RT; falling back to release engine" >&2
	MODE=release
fi

if [ ! -f "$BUNDLE/lib/libapp.so" ]; then
	echo "lws-hmi-hmi-launch: missing release AOT $BUNDLE/lib/libapp.so" >&2
	exit 1
fi

# Release path must match pre-P1.5 hmi.service: no LD_LIBRARY_PATH / ICU overrides.
exec /usr/bin/flutter-pi --release -o "$FLUTTER_PI_ORIENTATION" "$BUNDLE"
