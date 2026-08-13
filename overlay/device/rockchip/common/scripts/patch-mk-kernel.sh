#!/usr/bin/env bash
# Owned linux-sdk uses canonical kernel/ (no kernel-N.N sibling + symlink).
set -euo pipefail

target="$1"
marker='lws-hmi: canonical kernel/ layout'

if grep -q "$marker" "$target" 2>/dev/null; then
  exit 0
fi

python3 - "$target" <<'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

old = """\t# Update kernel
\tKERNEL_DIR=kernel-$RK_KERNEL_VERSION
\tnotice "\\nSwitching to $KERNEL_DIR"
\tif [ ! -d "$KERNEL_DIR" ]; then
\t\terror "$KERNEL_DIR not exist!"
\t\texit 1
\tfi

\trm -rf kernel
\tln -rsf $KERNEL_DIR kernel"""

new = """\t# Update kernel
\tKERNEL_DIR=kernel-$RK_KERNEL_VERSION
\tnotice "\\nSwitching to $KERNEL_DIR"
\tif [ ! -d "$KERNEL_DIR" ]; then
\t\t# lws-hmi: canonical kernel/ layout
\t\tif [ -d kernel ] && [ ! -L kernel ] && \\
\t\t\t[ "$(kernel_version_raw)" = "$RK_KERNEL_VERSION" ]; then
\t\t\tnotice "Using canonical kernel/ (version $RK_KERNEL_VERSION)"
\t\t\treturn 0
\t\tfi
\t\terror "$KERNEL_DIR not exist!"
\t\texit 1
\tfi

\trm -rf kernel
\tln -rsf $KERNEL_DIR kernel"""

if old not in text:
    sys.stderr.write(f"ERROR: mk-kernel.sh switch block not found in {path}\n")
    sys.exit(1)

text = text.replace(old, new, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY

echo "patched: $target ($marker)"
