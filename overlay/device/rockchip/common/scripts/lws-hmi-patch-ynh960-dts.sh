#!/usr/bin/env bash
# Append lws-hmi DTSI includes to Innohi customer_board_ynh960.dtsi (idempotent).
set -euo pipefail

CUSTOMER_DTSI="${1:?customer_board_ynh960.dtsi path required}"
shift

KERNEL_DTS_DIR="$(dirname "$CUSTOMER_DTSI")"

patch_innohi_usbhost_off() {
	# Innohi board enables usbhost_dwc3 in the middle of the file; our #include runs
	# at the end but patch here so a stale partial merge cannot leave host=okay.
	python3 - "$CUSTOMER_DTSI" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8", errors="replace").read()
orig = text

for label in ("usbhost_dwc3", "usbhost30", "combphy1_usq"):
    text, n = re.subn(
        rf"(&{label}\s*\{{[^{{}}]*?)status\s*=\s*\"okay\"",
        r'\1status = "disabled"',
        text,
        count=1,
        flags=re.S,
    )
    if n:
        print(f"overlay: {label} status -> disabled in {path}")

if text != orig:
    open(path, "w", encoding="utf-8").write(text)
PY
}

include_dtsi() {
  local src="$1"
  local marker="$2"
  local dst="$KERNEL_DTS_DIR/$(basename "$src")"

  cp -f "$src" "$dst"
  if grep -q "$marker" "$CUSTOMER_DTSI" 2>/dev/null; then
    echo "overlay: $CUSTOMER_DTSI already includes $marker"
    return 0
  fi
  cat >>"$CUSTOMER_DTSI" <<EOF

#include "$marker" /* lws-hmi ynh960 */
EOF
  echo "overlay: patched $CUSTOMER_DTSI ($marker)"
}

patch_innohi_usbhost_off

while [[ $# -ge 2 ]]; do
  include_dtsi "$1" "$2"
  shift 2
done

[[ $# -eq 0 ]] || {
  echo "usage: $0 customer.dtsi /path/lws.dtsi marker-name.dtsi ..." >&2
  exit 1
}
