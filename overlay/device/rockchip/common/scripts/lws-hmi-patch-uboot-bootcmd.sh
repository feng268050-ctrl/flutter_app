#!/usr/bin/env bash
# Patch rockchip-common.h: Linux GPT boots FIT first (skip boot_android hang).
set -euo pipefail

header="$1"
marker='lws-hmi: Linux boot_fit first'

[[ -r "$header" ]] || {
  echo "WARNING: $header missing; skip uboot bootcmd patch" >&2
  exit 0
}

if grep -q "$marker" "$header" 2>/dev/null && ! grep -q 'boot_android' "$header" 2>/dev/null; then
  exit 0
fi

python3 - "$header" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
marker = "lws-hmi: Linux boot_fit first"

old = (
    '#else\n'
    '#define RKIMG_BOOTCOMMAND\t\t\t\\\n'
    '\t"boot_android ${devtype} ${devnum};"\t\\\n'
    '\t"boot_fit;"\t\t\t\t\\\n'
    '\t"bootrkp;"\t\t\t\t\\\n'
    '\t"run distro_bootcmd;"\n'
    '#endif'
)
new = (
    f'#else /* {marker} */\n'
    '#define RKIMG_BOOTCOMMAND\t\t\t\\\n'
    '\t"run rkimg_bootdev;"\t\t\t\\\n'
    '\t"boot_fit;"\t\t\t\t\\\n'
    '\t"run distro_bootcmd;"\n'
    '#endif'
)

if old not in text:
    import re
    # Re-patch older lws-hmi block that still ran boot_android before boot_fit.
    pat = re.compile(
        r'#else /\* lws-hmi: Linux boot_fit first \*/\n'
        r'#define RKIMG_BOOTCOMMAND.*?\n'
        r'\t"run rkimg_bootdev;".*?\n'
        r'(?:\t"boot_android.*?\n)?'
        r'\t"boot_fit;".*?\n'
        r'(?:\t"bootrkp;".*?\n)?'
        r'\t"run distro_bootcmd;"\n'
        r'#endif',
        re.DOTALL,
    )
    if pat.search(text):
        text = pat.sub(new, text, count=1)
        open(path, "w", encoding="utf-8").write(text)
        print(f"re-patched {path}: bootcmd = rkimg_bootdev; boot_fit; ...")
        sys.exit(0)
    if marker in text:
        sys.exit(0)
    raise SystemExit(f"RKIMG_BOOTCOMMAND block not found in {path}")

open(path, "w", encoding="utf-8").write(text.replace(old, new, 1))
print(f"patched {path}: bootcmd = rkimg_bootdev; boot_fit; ...")
PY
