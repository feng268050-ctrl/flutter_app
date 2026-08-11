#!/usr/bin/env bash
# Build Flutter app release AOT bundle → overlay install prefix (eLinux meta-flutter).
# Convention: *_hmi → /opt/hmi (hmi.service); other apps (e.g. os_settings) → /opt/<APP>.
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
DEST="$OVERLAY_APP"

hmi_bundle_init_flutter build-app

# Ship-asset prepare is per-app when process-library / control-board sources exist.
if [[ -d "$APP_DIR/assets/process-library" || -d "$APP_DIR/assets/firmware/control-board" ]]; then
	bash "$ROOT/scripts/prepare-hmi-ship-assets.sh"
fi

cd "$APP_DIR"
"$FLUTTER" pub get

hmi_bundle_assemble release aot_elf_release copy_flutter_bundle
hmi_bundle_install_release

echo "Installed APP=$APP bundle to $DEST (libapp.so + assets; engine $ENGINE_VER on rootfs)"
ls -la "$DEST" "$DEST/lib" "$DEST/data" 2>/dev/null || ls -la "$DEST"
