#!/usr/bin/env bash
# Build P2/P3/P5 platform libs in Buildroot, export → prebuilt/platform-packages/target (before build-rootfs).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/prebuilt-common.sh"

VERSION="$(read_version_file "$ROOT/overlay/third-party/platform.version" "1")"
STAMP_DIR="$ROOT/prebuilt/platform-packages/target"
FORCE="${FORCE:-0}"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"

PLATFORM_PACKAGES=(
  libmodbus
  yaml-cpp
  sqlite
  avahi
)

if prebuilt_ready "$STAMP_DIR" && [[ "$FORCE" != "1" ]]; then
  echo "platform-packages: ready at $STAMP_DIR"
  exit 0
fi

if [[ "$FORCE" == "1" ]]; then
  rm -rf "$ROOT/prebuilt/platform-packages"
fi

bash "$ROOT/scripts/br-make-packages.sh" platform-packages "${PLATFORM_PACKAGES[@]}"

bash "$ROOT/scripts/docker-run.sh" bash -lc "
  set -euo pipefail
  OUT=\"\${LWS_HMI_SDK_DIR:?}/buildroot/output/${BR_OUTPUT}\"
  require_glob() {
    local label=\"\$1\"
    shift
    shopt -s nullglob
    local matches=( \"\$OUT/target/\$1\" )
    shopt -u nullglob
    if [[ \${#matches[@]} -eq 0 ]]; then
      echo \"ERROR: missing platform artifact: \$OUT/target/\$1 (\$label)\" >&2
      exit 1
    fi
  }
  require_glob libmodbus 'usr/lib/libmodbus.so*'
  require_glob yaml-cpp 'usr/lib/libyaml-cpp.so*'
  require_glob sqlite 'usr/lib/libsqlite3.so*'
  if [[ ! -x \"\$OUT/target/usr/sbin/avahi-daemon\" ]]; then
    echo \"ERROR: missing platform artifact: \$OUT/target/usr/sbin/avahi-daemon\" >&2
    exit 1
  fi
"

bash "$ROOT/scripts/export-runtime-prebuilt.sh" platform

echo "platform-packages: done — prebuilt at $STAMP_DIR (make apply-overlay && make build-rootfs)"
