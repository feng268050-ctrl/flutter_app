#!/usr/bin/env bash
# Keep a single Innohi tree under linux-sdk/innohi/; drop innohi_board mirror.
# Idempotently retarget device scripts that still mention innohi_board.
# Usage: called from apply-overlay.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-${SDK:-$ROOT/linux-sdk}}"
INNOHI_ROOTFS="$SDK/innohi/rootfs"
BOARD="$SDK/innohi_board"

if [[ ! -d "$INNOHI_ROOTFS" ]]; then
  echo "WARNING: normalize-innohi-sdk: missing $INNOHI_ROOTFS — skip" >&2
  exit 0
fi

if [[ -e "$BOARD" ]]; then
  echo "normalize-innohi-sdk: removing duplicate $BOARD"
  rm -rf "$BOARD"
fi

# Rewrite leftover dual-tree paths in owned / patched SDK scripts.
rewrite_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if grep -q 'innohi_board' "$f" 2>/dev/null; then
    # rootfs_board first so it does not become innohi/rootfs_board
    sed -i.bak \
      -e 's|innohi_board/rootfs_board|innohi/rootfs|g' \
      -e 's|innohi_board/rootfs|innohi/rootfs|g' \
      -e 's|innohi_board/|innohi/|g' \
      "$f"
    rm -f "${f}.bak"
    echo "normalize-innohi-sdk: retargeted $(basename "$f")"
  fi
}

# Collapse dual-tree firmware fallback once both arms point at innohi/rootfs.
collapse_wifibt_fw() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  python3 - "$f" <<'PY'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    text = fh.read()
redundant = """\tINNOHI_FW="${CROOT}/innohi/rootfs/system/etc/firmware"
\tif [ ! -d "$INNOHI_FW" ]; then
\t\tINNOHI_FW="${CROOT}/innohi/rootfs/system/etc/firmware"
\tfi
\tif [ -d "$INNOHI_FW" ] && ls "$INNOHI_FW"/* >/dev/null 2>&1; then
\t\tcp -rf "$INNOHI_FW"/* \\
\t\t\t${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/vendor/etc/firmware/
\tfi
"""
simple = """\t# lws-hmi: post-wifibt innohi single-tree
\tINNOHI_FW="${CROOT}/innohi/rootfs/system/etc/firmware"
\tif [ -d "$INNOHI_FW" ] && ls "$INNOHI_FW"/* >/dev/null 2>&1; then
\t\tcp -rf "$INNOHI_FW"/* \\
\t\t\t${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/vendor/etc/firmware/
\tfi
"""
if redundant not in text:
    sys.exit(0)
text = text.replace(redundant, simple, 1)
text = text.replace(
    "# lws-hmi: post-wifibt innohi fix",
    "# lws-hmi: post-wifibt innohi single-tree",
)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(text)
print("normalize-innohi-sdk: collapsed post-wifibt firmware block")
PY
}

shopt -s nullglob
for f in \
  "$SDK/device/rockchip/common/scripts/post-wifibt.sh" \
  "$SDK/device/rockchip/common/scripts/mk-rootfs.sh" \
  "$SDK"/device/rockchip/common/post-hooks/*innohi* \
  "$SDK"/device/rockchip/common/post-hooks/*wifibt*; do
  rewrite_file "$f"
done
shopt -u nullglob

collapse_wifibt_fw "$SDK/device/rockchip/common/scripts/post-wifibt.sh"

echo "normalize-innohi-sdk: done (single tree: innohi/)"
