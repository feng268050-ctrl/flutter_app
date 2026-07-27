#!/usr/bin/env bash
# Soft smoke: confirm process-library DB / version on a live board, then remind
# the operator to apply a Quick Mode preset and verify Modbus readback in UI.
#
# Usage:
#   SN=<board-sn> IFACE=en8 bash scripts/process-library-modbus-smoke.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

IFACE="${IFACE:-}"
if [[ -z "$IFACE" && -z "${IP:-}" && -z "${CHIPID:-}" && -z "${SN:-}" ]]; then
	# Best-effort auto-select when a single USB-SSH board is present.
	mapfile -t _sel < <(bash "$ROOT/scripts/device-target.sh" --select 2>/dev/null || true)
	IFACE="${_sel[2]:-}"
fi

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

echo "==> process-library Modbus smoke (read-only checks)"
remote 'set -e
DB=/var/lib/hmi/process-library.db
if [[ ! -f "$DB" ]]; then
  echo "FAIL: missing $DB"
  exit 1
fi
echo "db: $DB ($(stat -c%s "$DB") bytes)"
if command -v sqlite3 >/dev/null 2>&1; then
  echo "-- meta --"
  sqlite3 "$DB" "SELECT source, library_version, row_count, content_sha256 FROM process_library_meta;"
  echo "-- counts --"
  sqlite3 "$DB" "SELECT kind, COUNT(*) FROM process_presets GROUP BY kind;"
else
  echo "sqlite3 not on device; skipped SQL checks"
fi
echo "-- drop zones --"
ls -la /var/lib/hmi/incoming/process-library 2>/dev/null || echo "(no incoming dir)"
ls -la /userdata/ota/process-library 2>/dev/null || echo "(no ota process-library dir)"
'

cat <<'EOF'

Manual Modbus apply check (UI):
  1. Open Quick Mode, pick Continuous / Stainless / thickness / gear.
  2. Apply parameters (or change selection so ProcessParameterApplier runs).
  3. Confirm toast/success and that laser work stays idle (interlock).
  4. Optionally: Settings → Device Information → Process Library Version matches meta.

Offline import check:
  1. Copy a converted package (manifest.json + *.json) to
     /var/lib/hmi/incoming/process-library/<pkg>/ via MTP or scp.
  2. Settings → Device Information → Update Process Library → Import.
  3. Confirm audit dialog and refreshed Process Library Version.
EOF
