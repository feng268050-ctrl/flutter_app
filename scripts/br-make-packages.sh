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

echo "br-make-packages (${LABEL}): ${PKG_LIST} in output/${BR_OUTPUT} ..."

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
  make O=\"\$OUT\" -j${JOBS} ${PKG_LIST}
"
