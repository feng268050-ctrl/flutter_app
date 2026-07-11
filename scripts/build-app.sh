#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

APP_DIR="$ROOT/app/lws_hmi"
DEST="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/opt/hmi"
PINNED_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.24.4")"
ENGINE_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-engine.version" "$PINNED_VER")"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
FLUTTER="$FLUTTER_INSTALL/bin/flutter"
if [[ ! -x "$FLUTTER" ]]; then
	die "pinned Flutter SDK missing at $FLUTTER_INSTALL

Run on host (not Docker):
  make fetch-flutter-sdk
  make link-flutter-sdk

Or set FLUTTER_SDK to a tree with install/bin/flutter (must match engine $ENGINE_VER)."
fi

export PATH="$FLUTTER_INSTALL/bin:${HOME}/.pub-cache/bin:$PATH"

flutter_version_line="$("$FLUTTER" --version 2>/dev/null | head -1 || true)"
if [[ "$flutter_version_line" != *"$PINNED_VER"* ]]; then
	path_flutter="$(command -v flutter 2>/dev/null || true)"
	die "Flutter SDK version mismatch (AOT libapp.so must match rootfs libflutter_engine.so $ENGINE_VER).

  Pinned:  Flutter $PINNED_VER ($FLUTTER)
  Active:  ${flutter_version_line:-<flutter --version failed>}
  PATH:    ${path_flutter:-<not found>}

Do not use system/PATH flutter (e.g. 3.41.x). Run:
  make fetch-flutter-sdk
  make build-app"
fi

ensure_flutterpi_tool() {
	if command -v flutterpi_tool >/dev/null 2>&1 \
		&& flutterpi_tool help >/dev/null 2>&1; then
		return 0
	fi
	echo "Installing flutterpi_tool for Flutter $PINNED_VER (Dart $($FLUTTER_INSTALL/bin/dart --version 2>/dev/null | awk '{print $2}'))..."
	flutter pub global deactivate flutterpi_tool >/dev/null 2>&1 || true
	flutter pub global activate flutterpi_tool
}
ensure_flutterpi_tool

cd "$APP_DIR"
flutter pub get

echo "Building flutter-pi release bundle (Flutter $PINNED_VER, arm64, meta-flutter)..."
flutterpi_tool build --arch=arm64 --release

LEGACY_BUNDLE="$APP_DIR/build/flutter-pi/meta-flutter-aarch64-generic"
FLUTTERPI_OUT="$APP_DIR/build/flutter_assets"

install_meta_flutter_bundle() {
	rm -rf "$DEST"
	if [[ -f "$LEGACY_BUNDLE/lib/libapp.so" ]]; then
		mkdir -p "$DEST"
		cp -a "$LEGACY_BUNDLE/." "$DEST/"
	elif [[ -f "$FLUTTERPI_OUT/app.so" ]]; then
		mkdir -p "$DEST/lib" "$DEST/data/flutter_assets"
		cp -a "$FLUTTERPI_OUT/app.so" "$DEST/lib/libapp.so"
		for item in "$FLUTTERPI_OUT"/*; do
			[[ -e "$item" ]] || continue
			base="$(basename "$item")"
			case "$base" in
			app.so | libflutter_engine.so | icudtl.dat | flutter-pi) continue ;;
			esac
			cp -a "$item" "$DEST/data/flutter_assets/"
		done
	else
		die "flutterpi_tool produced no bundle (expected $LEGACY_BUNDLE/lib/libapp.so or $FLUTTERPI_OUT/app.so)"
	fi

	# Engine + icudtl live on rootfs (/usr/lib, /usr/share/flutter) — not in the app bundle.
	rm -f \
		"$DEST/lib/libflutter_engine.so" \
		"$DEST/data/icudtl.dat" \
		"$DEST/data/flutter_assets/libflutter_engine.so" \
		"$DEST/data/flutter_assets/icudtl.dat" \
		"$DEST/data/flutter_assets/app.so" \
		"$DEST/data/flutter_assets/flutter-pi"
}
install_meta_flutter_bundle

echo "Installed HMI app bundle to $DEST (libapp.so + assets only; engine $ENGINE_VER on rootfs)"
ls -la "$DEST" "$DEST/lib" "$DEST/data" 2>/dev/null || ls -la "$DEST"
