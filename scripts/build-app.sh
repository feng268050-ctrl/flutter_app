#!/usr/bin/env bash
# Build Flutter app release AOT bundle → app/<APP>/build/bundle/release (eLinux meta-flutter).
# Convention: *_hmi → device /opt/hmi (hmi.service); other apps → /opt/<APP>.
# build-rootfs copies bundle trees into rootfs; push-app reads the same bundle path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=app-select.sh
source "$ROOT/scripts/app-select.sh"
# shellcheck source=hmi-bundle-common.sh
source "$ROOT/scripts/hmi-bundle-common.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

app_select_resolve

hmi_bundle_init_flutter build-app

# Ship-asset prepare is per-app when process-library / control-board sources exist.
if [[ -d "$APP_DIR/assets/process-library" || -d "$APP_DIR/assets/firmware/control-board" ]]; then
	bash "$ROOT/scripts/prepare-hmi-ship-assets.sh"
fi

cd "$APP_DIR"
"$FLUTTER" pub get

hmi_bundle_assemble release aot_elf_release copy_flutter_bundle
hmi_bundle_install_release

echo "Installed APP=$APP bundle to $APP_BUNDLE_RELEASE (libapp.so + assets; engine $ENGINE_VER on rootfs)"
ls -la "$APP_BUNDLE_RELEASE" "$APP_BUNDLE_RELEASE/lib" "$APP_BUNDLE_RELEASE/data" 2>/dev/null \
	|| ls -la "$APP_BUNDLE_RELEASE"
