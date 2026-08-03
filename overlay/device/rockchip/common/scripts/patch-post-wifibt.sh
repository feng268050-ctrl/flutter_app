#!/usr/bin/env bash
# Guard post-wifibt: define CROOT when run from Buildroot, and stop copying the
# Innohi multi-vendor Wi-Fi/BT firmware kitchen sink into rootfs (OEM radio pack).
set -euo pipefail

target="$1"
marker='lws-hmi: post-wifibt oem-radio'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

# Ensure CROOT is defined at the start of build_wifibt (Buildroot post-hook path).
croot_snip = """build_wifibt()
{
\tcheck_config RK_KERNEL RK_WIFIBT RK_WIFIBT_MODULES || return 0"""

croot_new = """build_wifibt()
{
\t# lws-hmi: post-wifibt oem-radio
\tRK_SCRIPTS_DIR="${RK_SCRIPTS_DIR:-$(dirname "$(realpath "$0")")}"
\tRK_SDK_DIR="${RK_SDK_DIR:-$RK_SCRIPTS_DIR/../../../..}"
\tCROOT="${CROOT:-$RK_SDK_DIR}"

\tcheck_config RK_KERNEL RK_WIFIBT RK_WIFIBT_MODULES || return 0"""

oem_fw = """\t# lws-hmi: post-wifibt oem-radio — no rootfs kitchen-sink firmware
\t# Combo module blobs ship in the board OEM radio pack (make build-oem).
\t# Keep an empty vendor firmware dir so path aliases remain valid.
\tmkdir -p ${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/vendor/etc/firmware/
"""

# Drop prior Innohi full-tree copies (single-tree or dual-tree markers).
innohi_block = re.compile(
    r"\t# lws-hmi: post-wifibt innohi (?:single-tree|fix)\n"
    r"(?:\tINNOHI_FW=.*?firmware/\n)+",
    re.DOTALL,
)
# Also match un-marked Innohi cp blocks that normalize may leave.
raw_innohi = re.compile(
    r"\tINNOHI_FW=\"\$\{CROOT\}/innohi(?:_board)?/[^\"]+/firmware\"\n"
    r"(?:\tif \[ ! -d \"\$INNOHI_FW\" \]; then\n"
    r"\t\tINNOHI_FW=\"\$\{CROOT\}/innohi/[^\"]+/firmware\"\n"
    r"\tfi\n)?"
    r"\tif \[ -d \"\$INNOHI_FW\" \] && ls \"\$INNOHI_FW\"/\* >/dev/null 2>&1; then\n"
    r"\t\tcp -rf \"\$INNOHI_FW\"/\* \\\n"
    r"\t\t\t\$\{CROOT\}/buildroot/output/\$\{RK_BUILDROOT_CFG\}/target/vendor/etc/firmware/\n"
    r"\tfi\n",
)
legacy_cp = (
    "\tcp -rf ${CROOT}/innohi_board/rootfs_board/system/etc/firmware/*  "
    "${CROOT}/buildroot/output/rockchip_rk3566_rk3568/target/vendor/etc/firmware/\t"
)
legacy_cp_cfg = (
    "\tcp -rf ${CROOT}/innohi_board/rootfs_board/system/etc/firmware/*  "
    "${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/vendor/etc/firmware/\t"
)

changed = False

# Strip old marker comment at function head if present (re-inject below).
text2 = re.sub(
    r"(build_wifibt\(\)\n\{\n)\t# lws-hmi: post-wifibt innohi (?:single-tree|fix)\n",
    r"\1",
    text,
    count=1,
)
if text2 != text:
    text = text2
    changed = True

if "lws-hmi: post-wifibt oem-radio" not in text:
    if croot_snip in text:
        text = text.replace(croot_snip, croot_new, 1)
        changed = True
    elif "CROOT=\"${CROOT:-$RK_SDK_DIR}\"" in text and "build_wifibt()" in text:
        # Already has CROOT from prior patch; just mark oem-radio at head.
        text = text.replace(
            "build_wifibt()\n{",
            "build_wifibt()\n{\n\t# lws-hmi: post-wifibt oem-radio",
            1,
        )
        changed = True
    else:
        sys.stderr.write(f"ERROR: unexpected post-wifibt.sh in {path}\n")
        sys.exit(1)

# Remove Innohi kitchen-sink copy; insert oem-radio empty-dir ensure once.
if innohi_block.search(text):
    text = innohi_block.sub(oem_fw, text, count=1)
    changed = True
elif raw_innohi.search(text):
    text = raw_innohi.sub(oem_fw, text, count=1)
    changed = True
elif legacy_cp in text:
    text = text.replace(legacy_cp, oem_fw, 1)
    changed = True
elif legacy_cp_cfg in text:
    text = text.replace(legacy_cp_cfg, oem_fw, 1)
    changed = True
elif "post-wifibt oem-radio — no rootfs kitchen-sink firmware" not in text:
    # Insert after the vendor modules find/cp block if firmware block missing.
    ko_anchor = (
        "find -L ${CROOT}/kernel/ -name \"*.ko\"|xargs -i cp -rf {} "
        "${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/vendor/lib/modules/\n"
    )
    if ko_anchor in text:
        text = text.replace(ko_anchor, ko_anchor + oem_fw, 1)
        changed = True
    else:
        sys.stderr.write(f"ERROR: innohi/oem firmware block not found in {path}\n")
        sys.exit(1)

# Drop stale single-tree marker comments elsewhere.
text = text.replace(
    "# lws-hmi: post-wifibt innohi single-tree\n",
    "",
)
text = text.replace(
    "# lws-hmi: post-wifibt innohi fix\n",
    "",
)

if not changed and "lws-hmi: post-wifibt oem-radio" not in open(path, encoding="utf-8").read():
    sys.stderr.write(f"ERROR: failed to patch post-wifibt.sh in {path}\n")
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
