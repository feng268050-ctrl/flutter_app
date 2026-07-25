#!/usr/bin/env bash
# Build HMI debug bundle (ARM64 meta-flutter layout via flutterpi_tool).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=debug-runtime-common.sh
source "$ROOT/scripts/debug-runtime-common.sh"

APP_DIR="$ROOT/app/lws_hmi"
STAGING="$(debug_runtime_staging_dir "$ROOT")"
PINNED_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.24.4")"
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "$PINNED_VER")"
PI_TOOL_VER="$(read_version_file "$ROOT/overlay/buildroot/flutterpi_tool.version" "0.5.4")"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
FLUTTER="$FLUTTER_INSTALL/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
	die "pinned Flutter SDK missing at $FLUTTER_INSTALL

Run on host (not Docker):
  make fetch-flutter-sdk"
fi

export PATH="$FLUTTER_INSTALL/bin:${HOME}/.pub-cache/bin:$PATH"

flutter_version_line="$("$FLUTTER" --version 2>/dev/null | head -1 || true)"
if [[ "$flutter_version_line" != *"$PINNED_VER"* ]]; then
	die "Flutter SDK version mismatch (debug bundle must match rootfs engine $ENGINE_VER).

  Pinned:  Flutter $PINNED_VER ($FLUTTER)
  Active:  ${flutter_version_line:-<flutter --version failed>}

Do not use system/PATH flutter. Run:
  make fetch-flutter-sdk
  make build-debug-app"
fi

ensure_flutterpi_tool() {
	local active
	active="$(dart pub global list 2>/dev/null | awk '/^flutterpi_tool /{print $2}' || true)"
	if [[ "$active" == "$PI_TOOL_VER" ]] \
		&& command -v flutterpi_tool >/dev/null 2>&1 \
		&& flutterpi_tool help >/dev/null 2>&1; then
		return 0
	fi
	echo "Installing flutterpi_tool $PI_TOOL_VER for Flutter $PINNED_VER..."
	flutter pub global deactivate flutterpi_tool >/dev/null 2>&1 || true
	flutter pub global activate flutterpi_tool "$PI_TOOL_VER"
}
ensure_flutterpi_tool

cd "$APP_DIR"
flutter pub get

echo "Building HMI debug bundle (Flutter $PINNED_VER, flutterpi_tool $PI_TOOL_VER, arm64)..."
flutterpi_tool build --arch=arm64 --debug

ASSETS_OUT="$APP_DIR/build/flutter_assets"
[[ -f "$ASSETS_OUT/kernel_blob.bin" ]] || die "missing $ASSETS_OUT/kernel_blob.bin (HMI debug build failed)"

ENGINE_SRC="$ASSETS_OUT/libflutter_engine.so"
ICU_SRC="$ASSETS_OUT/icudtl.dat"
[[ -f "$ENGINE_SRC" ]] || die "missing debug engine in build output: $ENGINE_SRC"
[[ -f "$ICU_SRC" ]] || die "missing debug ICU in build output: $ICU_SRC"

HMI_STAGING="$STAGING/opt/hmi"
RUNTIME_STAGING="$STAGING/debug-runtime/$ENGINE_VER"
rm -rf "$STAGING"
mkdir -p "$HMI_STAGING/data/flutter_assets" "$RUNTIME_STAGING"

for item in "$ASSETS_OUT"/*; do
	[[ -e "$item" ]] || continue
	base="$(basename "$item")"
	case "$base" in
	libflutter_engine.so | icudtl.dat | flutter-pi) continue ;;
	esac
	cp -a "$item" "$HMI_STAGING/data/flutter_assets/"
done

cat >"$HMI_STAGING/runtime-mode.json" <<EOF
{"mode":"debug","engine_version":"${ENGINE_VER}"}
EOF

debug_runtime_write_manifest "$RUNTIME_STAGING" "$ENGINE_SRC" "$ICU_SRC" "$ENGINE_VER"

echo "Debug staging ready at $STAGING"
echo "  app:     $HMI_STAGING/data/flutter_assets/kernel_blob.bin"
echo "  runtime: $RUNTIME_STAGING/libflutter_engine.so"
