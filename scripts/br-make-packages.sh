#!/usr/bin/env bash
# Run Buildroot package targets inside the lws_hmi output tree (shared by build-*-runtime scripts).
set -euo pipefail

LABEL="${1:?usage: br-make-packages.sh <label> <pkg> [pkg...]}"
shift
if [[ $# -lt 1 ]]; then
  echo "usage: br-make-packages.sh <label> <pkg> [pkg...]" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
JOBS="${BUILD_JOBS:-4}"
PKG_LIST="$*"

# wayland-dirclean does not remove libs already copied into target/. A partial or
# older install can leave libwayland-egl.so.1 as a regular file; meson then
# fails with "already exists and is not a symlink" on reinstall.
needs_wayland_scrub() {
  case " ${PKG_LIST} " in
  *" wayland "*) return 0 ;;
  esac
  return 1
}

# Weston/eLinux packages need the default Weston defconfig (DRM backend…).
# flutter-pi package builds need the alternate flutter-pi defconfig.
# Other packages inherit LWS_HMI_WESTON (default 1 = Weston).
needs_wayland_defconfig() {
  case " ${PKG_LIST} " in
  *" wayland "*|*" weston "*|*" flutter-embedded-linux "*) return 0 ;;
  esac
  return 1
}

needs_flutter_pi_defconfig() {
  case " ${PKG_LIST} " in
  *" flutter-pi "*) return 0 ;;
  esac
  return 1
}

echo "br-make-packages (${LABEL}): ${PKG_LIST} in output/${BR_OUTPUT} ..."

# macOS builds use a Docker volume for linux-sdk — apply-overlay must run inside
# docker-run (with LWS_HMI_WESTON), not on the host tree only.
if needs_wayland_defconfig; then
  export LWS_HMI_WESTON=1
elif needs_flutter_pi_defconfig; then
  export LWS_HMI_WESTON=0
fi

bash "$ROOT/scripts/docker-run.sh" bash -lc "
  set -euo pipefail
  SDK_DIR=\"\${LWS_HMI_SDK_DIR:?}\"
  cd \"\${SDK_DIR}/buildroot\"
  OUT=output/${BR_OUTPUT}
  if [[ ! -d \"\$OUT\" ]]; then
    echo 'ERROR: Buildroot output missing — run: make lunch' >&2
    exit 1
  fi
  make O=\"\$OUT\" rockchip_rk3566_rk3568_lws_hmi_defconfig
  # Option flips (e.g. WPA_SUPPLICANT_DBUS) do not invalidate stamps — dirclean first.
  for pkg in ${PKG_LIST}; do
    make O=\"\$OUT\" \"\${pkg}-dirclean\" || true
  done
  if $(needs_wayland_scrub && echo true || echo false); then
    echo 'br-make-packages: scrub stale wayland libs from target/staging'
    rm -f \"\$OUT/target/usr/lib/libwayland-\"*.so*
    rm -f \"\$OUT/staging/usr/lib/libwayland-\"*.so*
    rm -f \"\$OUT/staging/usr/lib/pkgconfig/wayland-\"*.pc
  fi
  make O=\"\$OUT\" -j${JOBS} ${PKG_LIST}
"
