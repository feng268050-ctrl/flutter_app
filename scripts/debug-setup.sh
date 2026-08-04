#!/usr/bin/env bash
# Enable Flutter Custom Devices and install the lws-hmi device definition.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"

PINNED_VER="$(read_version_file "$ROOT/overlay/buildroot/flutter-sdk.version" "3.41.9")"
FLUTTER_INSTALL="$(bash "$ROOT/scripts/link-flutter-sdk.sh" --print)"
FLUTTER="$FLUTTER_INSTALL/bin/flutter"
SCHEMA="file://${FLUTTER_INSTALL}/packages/flutter_tools/static/custom-devices.schema.json"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[[ -x "$FLUTTER" ]] || die "pinned Flutter SDK missing at $FLUTTER_INSTALL (make fetch-flutter-sdk)"

export PATH="$FLUTTER_INSTALL/bin:${HOME}/.pub-cache/bin:$PATH"
flutter_version_line="$("$FLUTTER" --version 2>/dev/null | head -1 || true)"
[[ "$flutter_version_line" == *"$PINNED_VER"* ]] || die "Flutter SDK must be $PINNED_VER (got: ${flutter_version_line:-unknown})"

"$FLUTTER" config --enable-custom-devices >/dev/null

case "$(uname -s)" in
Darwin | Linux) CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/flutter/custom_devices.json" ;;
*) CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/flutter/custom_devices.json" ;;
esac
if [[ ! -d "$(dirname "$CONFIG")" && -d "${HOME}/Library/Application Support/flutter" ]]; then
	CONFIG="${HOME}/Library/Application Support/flutter/custom_devices.json"
fi
mkdir -p "$(dirname "$CONFIG")"

PING="$ROOT/scripts/debug-custom-device/ping.sh"
POST_BUILD="$ROOT/scripts/debug-custom-device/post-build.sh"
INSTALL="$ROOT/scripts/debug-custom-device/install.sh"
UNINSTALL="$ROOT/scripts/debug-custom-device/uninstall.sh"
RUN_DEBUG="$ROOT/scripts/debug-custom-device/run-debug.sh"
FORWARD="$ROOT/scripts/debug-custom-device/forward-port.sh"

for script in "$PING" "$POST_BUILD" "$INSTALL" "$UNINSTALL" "$RUN_DEBUG" "$FORWARD"; do
	[[ -x "$script" ]] || chmod +x "$script"
done

python3 - "$CONFIG" "$SCHEMA" "$PING" "$POST_BUILD" "$INSTALL" "$UNINSTALL" "$RUN_DEBUG" "$FORWARD" "$PINNED_VER" <<'PY'
import json, sys

config_path, schema, ping, post_build, install, uninstall, run_debug, forward, flutter_ver = sys.argv[1:]

device = {
    "id": "lws-hmi",
    "label": "lws-hmi (USB-SSH / SSH)",
    "sdkNameAndVersion": f"eLinux / Flutter {flutter_ver}",
    "platform": "linux-arm64",
    "enabled": True,
    "ping": ["bash", ping],
    "postBuild": ["bash", post_build],
    "install": ["bash", install],
    "uninstall": ["bash", uninstall],
    "runDebug": ["bash", run_debug],
    "forwardPort": ["bash", forward, "${hostPort}", "${devicePort}"],
    "forwardPortSuccessRegex": "Port forwarding success",
}

with open(config_path, "w", encoding="utf-8") as fh:
    json.dump({"$schema": schema, "custom-devices": [device]}, fh, indent=2)
    fh.write("\n")

print(f"Installed lws-hmi custom device at {config_path}")
PY

echo "Custom device ready. Verify with:"
echo "  $FLUTTER devices"
echo "  $FLUTTER doctor"
echo "Select board: SN=... or IP=... (registered: make connect <ip>); put in .env for IDE."
