#!/usr/bin/env bash
# Push latest bundled control-board firmware to device for immediate upgrade
# (no confirm, no version gate; operator `make upgrade-control-board` helper).
#
# Device-side: app watches `/run/hmi/upgrade-control-board.cmd` and loads the
# pushed `.bin` file to run Modbus firmware transfer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

usage() {
  cat <<EOF
Usage: make upgrade-control-board [FIRMWARE_BIN=/abs/path/to/LSW01H####S####.bin]

By default picks the highest software version (S####) under:
  app/lws_hmi/assets/firmware/control-board/LSW01H*.bin

Then uploads to:
  /run/hmi/control-board-upgrade/<basename>
and writes:
  /run/hmi/upgrade-control-board.cmd

Prereq: HMI app is running (hmi.service) so the command watcher can react.
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

remote() {
  usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

upload_with_progress() {
  local src="$1"
  local dest="$2"
  python3 "$ROOT/scripts/stream-file-progress.py" "$src" |
    remote "cat >'$dest'"
}

ASSET_DIR="$ROOT/app/lws_hmi/assets/firmware/control-board"
CMD_PATH="/run/hmi/upgrade-control-board.cmd"
UPGRADE_DIR="/run/hmi/control-board-upgrade"
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
REMOTE_BIN="${UPGRADE_DIR}/${BASE}"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: selected firmware: $FIRMWARE_BIN"
echo "INFO: pushing to: $REMOTE_BIN"

remote "mkdir -p '$UPGRADE_DIR' && rm -f '$REMOTE_BIN'"
upload_with_progress "$FIRMWARE_BIN" "$REMOTE_BIN"

echo "INFO: writing upgrade command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'upgrade %s\\n' '$REMOTE_BIN' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "OK: control-board upgrade command sent (no confirm, no version gate)"
echo "INFO: filter device logs with: make logs GREP=BundledFirmwareBootstrap"
