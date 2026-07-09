#!/usr/bin/env bash
# Append lws-hmi DTSI includes to Innohi customer_board_ynh960.dtsi (idempotent).
set -euo pipefail

CUSTOMER_DTSI="${1:?customer_board_ynh960.dtsi path required}"
shift

KERNEL_DTS_DIR="$(dirname "$CUSTOMER_DTSI")"

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

while [[ $# -ge 2 ]]; do
  include_dtsi "$1" "$2"
  shift 2
done

[[ $# -eq 0 ]] || {
  echo "usage: $0 customer.dtsi /path/lws.dtsi marker-name.dtsi ..." >&2
  exit 1
}
