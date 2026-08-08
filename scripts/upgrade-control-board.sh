#!/usr/bin/env bash
# Sign + host-HTTP serve control-board firmware; device downloads, verifies, applies
# (no confirm, no version gate; operator `make upgrade-control-board` helper).
#
# Device-side: app watches `/run/hmi/upgrade-control-board.cmd` for:
#   download <http://host:port/LSW01H….bin>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/peripheral-ota-http.sh
source "$ROOT/scripts/peripheral-ota-http.sh"

usage() {
  cat <<EOF
Usage: make upgrade-control-board [FIRMWARE_BIN=/abs/path/to/LSW01H####S####.bin]

By default picks the highest software version (S####) under:
  app/lws_hmi/assets/firmware/control-board/LSW01H*.bin

Signs with OTA_SIGNING_KEY (default keys/ota/ed25519.pem), serves over
ephemeral host HTTP, and writes:
  /run/hmi/upgrade-control-board.cmd  →  download <url>

Env: OTA_HTTP_HOST / OTA_HTTP_PORT / OTA_SIGNING_KEY / SN= / IP=

Prereq: HMI app is running (hmi.service) so the command watcher can react.
EOF
}

die() { peripheral_ota_die "$@"; }

remote() {
  usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

ASSET_DIR="$ROOT/app/lws_hmi/assets/firmware/control-board"
CMD_PATH="/run/hmi/upgrade-control-board.cmd"
export ASSET_DIR

[[ -d "$ASSET_DIR" ]] || die "missing asset dir: $ASSET_DIR"
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

if [[ -z "${FIRMWARE_BIN:-}" ]]; then
  FIRMWARE_BIN="$(
    python3 - <<'PY'
import glob, os, re

asset_dir = os.environ["ASSET_DIR"]
pat = re.compile(r"^LSW01H(?P<hw>\d{4})S(?P<sw>\d{4})\.bin$", re.I)
best = None  # (sw, hw, path)
for p in glob.glob(os.path.join(asset_dir, "LSW01H*.bin")):
    name = os.path.basename(p)
    m = pat.match(name)
    if not m:
        continue
    hw = int(m.group("hw"))
    sw = int(m.group("sw"))
    cand = (sw, hw, p)
    if best is None or (cand[0], cand[1]) > (best[0], best[1]):
        best = cand
print("" if best is None else best[2])
PY
  )"
fi

[[ -n "$FIRMWARE_BIN" ]] || die "no firmware bin found under $ASSET_DIR"
[[ -f "$FIRMWARE_BIN" ]] || die "firmware file not found: $FIRMWARE_BIN"

BASE="$(basename "$FIRMWARE_BIN")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-cb-fw.XXXXXX")"
WORK_BIN="$WORK_DIR/$BASE"
WORK_SIG="$WORK_DIR/${BASE}.sig"
cp -f "$FIRMWARE_BIN" "$WORK_BIN"

cleanup() {
  peripheral_ota_stop_http_server
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: selected firmware: $FIRMWARE_BIN"
peripheral_ota_sign "$WORK_BIN" "$WORK_SIG"

peripheral_ota_resolve_http_bind
echo "INFO: serving on $OTA_HTTP_BIND (device will HTTP GET)..."
peripheral_ota_start_http_server "$WORK_BIN" "$WORK_SIG" "$BASE"
echo "INFO: package_url=$PACKAGE_URL"

echo "INFO: writing download command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'download %s\\n' '$PACKAGE_URL' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "INFO: waiting for device HTTP GET of bin + .sig..."
peripheral_ota_wait_transfer_complete 600

peripheral_ota_stop_http_server
trap - EXIT
rm -rf "$WORK_DIR"

echo "OK: transfer complete — device will verify and Modbus-flash (no confirm, no version gate)"
echo "INFO: filter device logs with: make logs GREP=BundledFirmwareBootstrap"
