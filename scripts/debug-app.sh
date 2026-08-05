#!/usr/bin/env bash
# Launch Flutter debug session on lws-hmi via Custom Devices (same path as IDE).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app/lws_hmi"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

PINNED_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.41.9")"
FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
FLUTTER="$FLUTTER_INSTALL/bin/flutter"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -x "$FLUTTER" ]] || die "pinned Flutter SDK missing (make fetch-flutter-sdk)"
export PATH="$FLUTTER_INSTALL/bin:${HOME}/.pub-cache/bin:$PATH"

bash "$ROOT/scripts/prepare-debug-host.sh"
bash "$ROOT/scripts/debug-setup.sh"
bash "$ROOT/scripts/build-debug-app.sh"

cd "$APP_DIR"
echo "Starting Flutter debug on lws-hmi (Ctrl+C detaches IDE tunnel; app keeps running on device)..."
echo "Tip: IP=<addr> / SN=SIM-EMU (EMU) / SN=... via env/.env when multiple boards (make devices)."
exec "$FLUTTER" run -d lws-hmi --debug --no-pub --no-track-widget-creation
