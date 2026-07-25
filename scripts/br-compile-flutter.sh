#!/usr/bin/env bash
# Swap in *.compile.mk inside the SDK tree used by Buildroot, build one package, restore.
set -euo pipefail

PKG="${1:?usage: br-compile-flutter.sh flutter-engine}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BR_OUTPUT="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
JOBS="${BUILD_JOBS:-4}"

case "$PKG" in
flutter-engine) ;;
flutter-pi)
	echo "ERROR: flutter-pi package was removed; use flutter-engine / flutter-embedded-linux" >&2
	exit 2
	;;
*)
	echo "ERROR: unsupported package '$PKG' (expected flutter-engine)" >&2
	exit 2
	;;
esac

echo "br-compile-flutter: building ${PKG} (compile.mk) in buildroot output ${BR_OUTPUT} ..."

bash "$ROOT/scripts/docker-run.sh" bash -lc "
  set -euo pipefail
  HMI_ROOT=\"\${LWS_HMI_ROOT:?LWS_HMI_ROOT not set}\"
  SDK_DIR=\"\${LWS_HMI_SDK_DIR:?LWS_HMI_SDK_DIR not set}\"
  # shellcheck source=scripts/build-env.sh
  source \"\${HMI_ROOT}/scripts/build-env.sh\"
  export LWS_HMI_DOCKER=1 LWS_HMI_ROOT=\"\${HMI_ROOT}\"
  setup_build_env
  PKG='${PKG}'
  SDK_PKG=\"\${SDK_DIR}/buildroot/package/\${PKG}\"
  COMPILE_MK=\"\${HMI_ROOT}/overlay/buildroot/package/\${PKG}/\${PKG}.compile.mk\"
  ACTIVE_MK=\"\${SDK_PKG}/\${PKG}.mk\"
  BACKUP=\"\${SDK_PKG}/\${PKG}.mk.lws-prebuilt-swap\"

  if [[ ! -f \"\$COMPILE_MK\" ]]; then
    echo \"ERROR: missing \$COMPILE_MK\" >&2
    exit 1
  fi
  if [[ ! -f \"\$ACTIVE_MK\" ]]; then
    echo \"ERROR: missing \$ACTIVE_MK (run: make apply-overlay)\" >&2
    exit 1
  fi

  cp -a \"\$ACTIVE_MK\" \"\$BACKUP\"
  cp -a \"\$COMPILE_MK\" \"\$ACTIVE_MK\"

  restore_patches() {
    local stash=\"\${SDK_PKG}/.lws-prebuilt-patches-disabled\"
    [[ -d \"\$stash\" ]] || return 0
    shopt -s nullglob
    for p in \"\$stash\"/*.patch; do mv \"\$p\" \"\$SDK_PKG/\"; done
    shopt -u nullglob
    rmdir \"\$stash\" 2>/dev/null || true
  }
  stash_patches() {
    local stash=\"\${SDK_PKG}/.lws-prebuilt-patches-disabled\"
    mkdir -p \"\$stash\"
    shopt -s nullglob
    for p in \"\${SDK_PKG}\"/*.patch; do mv \"\$p\" \"\$stash/\"; done
    shopt -u nullglob
  }

  restore_patches

  restore() {
    [[ -f \"\$BACKUP\" ]] && mv -f \"\$BACKUP\" \"\$ACTIVE_MK\"
    stash_patches
  }
  trap restore EXIT

  cd \"\${SDK_DIR}/buildroot\"
  OUT=output/${BR_OUTPUT}
  if [[ ! -d \"\$OUT\" ]]; then
    echo 'ERROR: Buildroot output missing — run: make lunch' >&2
    exit 1
  fi
  make O=\"\$OUT\" -j${JOBS} \${PKG}-dirclean \${PKG}
"

echo "br-compile-flutter: ${PKG} package build finished"
