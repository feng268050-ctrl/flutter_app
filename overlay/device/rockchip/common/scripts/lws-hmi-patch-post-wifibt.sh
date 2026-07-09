#!/usr/bin/env bash
# Guard Innohi BT firmware copy + define CROOT when post-wifibt runs from Buildroot.
set -euo pipefail

target="$1"
marker='lws-hmi: post-wifibt innohi fix'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

croot_snip = """build_wifibt()
{
\tcheck_config RK_KERNEL RK_WIFIBT RK_WIFIBT_MODULES || return 0"""

croot_new = """build_wifibt()
{
\t# lws-hmi: post-wifibt innohi fix
\tRK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
\tRK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"
\tCROOT="${CROOT:-$RK_SDK_DIR}"

\tcheck_config RK_KERNEL RK_WIFIBT RK_WIFIBT_MODULES || return 0"""

if croot_snip not in text:
    sys.stderr.write(f"ERROR: unexpected post-wifibt.sh in {path}\n")
    sys.exit(1)
text = text.replace(croot_snip, croot_new, 1)

old_fw = "\tcp -rf ${CROOT}/innohi_board/rootfs_board/system/etc/firmware/*  ${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target/vendor/etc/firmware/\t"

new_fw = """\tINNOHI_FW="${CROOT}/innohi_board/rootfs_board/system/etc/firmware"
\tif [ ! -d "$INNOHI_FW" ]; then
\t\tINNOHI_FW="${CROOT}/innohi/rootfs/system/etc/firmware"
\tfi
\tif [ -d "$INNOHI_FW" ] && ls "$INNOHI_FW"/* >/dev/null 2>&1; then
\t\tcp -rf "$INNOHI_FW"/* \\
\t\t\t${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target/vendor/etc/firmware/
\tfi
"""

if old_fw not in text:
    sys.stderr.write(f"ERROR: innohi firmware block not found in {path}\n")
    sys.exit(1)
text = text.replace(old_fw, new_fw, 1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
