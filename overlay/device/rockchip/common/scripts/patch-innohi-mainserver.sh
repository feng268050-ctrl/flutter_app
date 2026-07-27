#!/usr/bin/env bash
# Wrap Innohi MainServer / etc/init.d block — skip for lws_hmi systemd rootfs.
set -euo pipefail

target="$1"
marker='lws-hmi: systemd skips MainServer (innohi single-tree)'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

text = text.replace("innohi_board/rootfs_board", "innohi/rootfs")
text = text.replace("innohi_board/rootfs", "innohi/rootfs")

old_marker = "lws-hmi: systemd + flutter-pi skips Innohi MainServer/S99-init rebuild"
new_marker = "lws-hmi: systemd skips MainServer (innohi single-tree)"
if old_marker in text:
    text = text.replace(old_marker, new_marker, 1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    sys.exit(0)

br_out = r"(?:\$\{RK_BUILDROOT_CFG\}|rockchip_rk3566_rk3568)"

pat = re.compile(
    rf"\t\t\n"
    rf"##############拷贝开机服务###############################################\t\n"
    rf"\tcd \$\{{CROOT\}}/buildroot/output/{br_out}/target\n"
    rf"\tsudo cp -rf \$\{{CROOT\}}/innohi/rootfs/usr/bin/MainServer  usr/bin/\n"
    rf"\tsudo cp -rf \$\{{CROOT\}}/innohi/rootfs/usr/bin/ParamUpdate  usr/bin/\n"
    rf'\tsudo echo "#! /bin/sh" > etc/init.d/S99-init.sh\n'
    rf'\techo "/usr/bin/rk_wifi_init /dev/ttyS1 &" >> etc/init.d/S99-init.sh\n'
    rf'\tsudo echo "/usr/bin/MainServer &" >> etc/init.d/S99-init.sh\n'
    rf"\tsudo chown \$USER:\$USER \. -R\n"
    rf"\tcd -;\n"
    rf"\tcp -rf \$\{{CROOT\}}/innohi/rootfs/usr/bin/\*  "
    rf"\$\{{CROOT\}}/buildroot/output/{br_out}/target/usr/bin/\n"
    rf"\t\n"
    rf"\t####再编译一次，打包innohi rootfs#####\n"
    rf'\t"\$RK_SCRIPTS_DIR/mk-buildroot.sh" \$RK_BUILDROOT_CFG "\$IMAGE_DIR"\n'
    rf"\t\t\n"
    rf"#############################################################",
    re.MULTILINE,
)

guarded = """\t\t
# lws-hmi: systemd skips MainServer (innohi single-tree)
if [[ "${RK_BUILDROOT_CFG:-}" != *lws_hmi* ]]; then
##############拷贝开机服务###############################################\t
\tcd ${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target
\tsudo cp -rf ${CROOT}/innohi/rootfs/usr/bin/MainServer  usr/bin/
\tsudo cp -rf ${CROOT}/innohi/rootfs/usr/bin/ParamUpdate  usr/bin/
\tsudo echo "#! /bin/sh" > etc/init.d/S99-init.sh
\techo "/usr/bin/rk_wifi_init /dev/ttyS1 &" >> etc/init.d/S99-init.sh
\tsudo echo "/usr/bin/MainServer &" >> etc/init.d/S99-init.sh
\tsudo chown $USER:$USER . -R
\tcd -;
\tcp -rf ${CROOT}/innohi/rootfs/usr/bin/*  ${CROOT}/buildroot/output/${RK_BUILDROOT_CFG}/target/usr/bin/
\t
\t####再编译一次，打包innohi rootfs#####
\t"$RK_SCRIPTS_DIR/mk-buildroot.sh" $RK_BUILDROOT_CFG "$IMAGE_DIR"
fi
\t\t
#############################################################"""

new_text, n = pat.subn(guarded, text, count=1)
if n == 0:
    sys.stderr.write(f"WARNING: Innohi MainServer block not found in {path}\n")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    sys.exit(0)

with open(path, "w", encoding="utf-8") as f:
    f.write(new_text)
PY
