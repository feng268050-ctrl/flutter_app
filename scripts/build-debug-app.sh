#!/usr/bin/env bash
# Build HMI debug JIT bundle (linux-arm64 meta-flutter layout via flutter assemble).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=hmi-bundle-common.sh
source "$ROOT/scripts/hmi-bundle-common.sh"

APP_DIR="$ROOT/app/lws_hmi"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

hmi_bundle_init_flutter build-debug-app

bash "$ROOT/scripts/prepare-hmi-ship-assets.sh"

cd "$APP_DIR"
"$FLUTTER" pub get

hmi_bundle_assemble debug copy_flutter_bundle
hmi_bundle_install_debug_staging
