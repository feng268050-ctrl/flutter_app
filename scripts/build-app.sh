#!/usr/bin/env bash
# Build HMI release AOT bundle → overlay /opt/hmi (eLinux meta-flutter layout).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=prebuilt-common.sh
source "$ROOT/scripts/prebuilt-common.sh"
# shellcheck source=hmi-bundle-common.sh
source "$ROOT/scripts/hmi-bundle-common.sh"

APP_DIR="$ROOT/app/lws_hmi"
DEST="$ROOT/overlay/board/rockchip/rk3566_rk3568/rootfs-overlay/opt/hmi"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

hmi_bundle_init_flutter build-app

cd "$APP_DIR"
"$FLUTTER" pub get

hmi_bundle_assemble release aot_elf_release copy_flutter_bundle
hmi_bundle_install_release

echo "Installed HMI bundle to $DEST (libapp.so + assets; engine $ENGINE_VER on rootfs)"
ls -la "$DEST" "$DEST/lib" "$DEST/data" 2>/dev/null || ls -la "$DEST"
