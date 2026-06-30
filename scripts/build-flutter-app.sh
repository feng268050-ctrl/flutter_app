#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app/lws_hmi_app"
DEST="$ROOT/overlay/board/rockchip/rk3566_rk3568/lws-hmi-fs-overlay/opt/hmi"

if ! command -v flutter >/dev/null 2>&1; then
  echo "ERROR: flutter SDK not found in PATH" >&2
  exit 1
fi

export PATH="${PATH}:${HOME}/.pub-cache/bin"
if ! command -v flutterpi_tool >/dev/null 2>&1; then
  echo "Installing flutterpi_tool..."
  flutter pub global activate flutterpi_tool
fi

cd "$APP_DIR"
flutter pub get

echo "Building flutter-pi release bundle (arm64, meta-flutter layout)..."
flutterpi_tool build --arch=arm64 --release

BUNDLE="$APP_DIR/build/flutter-pi/meta-flutter-aarch64-generic"
if [[ ! -f "$BUNDLE/lib/libapp.so" ]]; then
  echo "ERROR: expected $BUNDLE/lib/libapp.so after build" >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$BUNDLE/." "$DEST/"
echo "Installed HMI bundle to $DEST"
ls -la "$DEST"
