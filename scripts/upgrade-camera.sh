#!/usr/bin/env bash
# Push latest bundled camera firmware ZIP to device for immediate upgrade
# (no confirm, no version gate; operator `make upgrade-camera` helper).
#
# Device-side: app watches `/run/hmi/upgrade-camera.cmd` and loads the
# pushed `.zip` to run CGI flash + reboot + wait-online.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

usage() {
  cat <<EOF
Usage: make upgrade-camera [FIRMWARE_ZIP=/abs/path/to/MODEL-vX.Y.Z\\ buildYYYYMMDD.zip]

By default picks the newest SemVer then build under:
  app/lws_hmi/assets/firmware/camera/*.zip

Then uploads to:
  /run/hmi/camera-upgrade/<basename>
and writes:
  /run/hmi/upgrade-camera.cmd

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

ASSET_DIR="$ROOT/app/lws_hmi/assets/firmware/camera"
CMD_PATH="/run/hmi/upgrade-camera.cmd"
UPGRADE_DIR="/run/hmi/camera-upgrade"
export ASSET_DIR

[[ -d "$ASSET_DIR" ]] || die "missing asset dir: $ASSET_DIR"
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

if [[ -z "${FIRMWARE_ZIP:-}" ]]; then
  FIRMWARE_ZIP="$(
    python3 - <<'PY'
import glob, os, re

asset_dir = os.environ["ASSET_DIR"]
pat = re.compile(
    r"^(?P<model>[A-Za-z0-9]+)-v(?P<maj>\d+)\.(?P<min>\d+)\.(?P<patch>\d+) "
    r"build(?P<build>\d{8})\.zip$",
    re.I,
)
best = None  # ((maj,min,patch), build, path)
for p in glob.glob(os.path.join(asset_dir, "*.zip")):
    name = os.path.basename(p)
    m = pat.match(name)
    if not m:
        continue
    sem = (int(m.group("maj")), int(m.group("min")), int(m.group("patch")))
    build = int(m.group("build"))
    cand = (sem, build, p)
    if best is None or (cand[0], cand[1]) > (best[0], best[1]):
        best = cand
print("" if best is None else best[2])
PY
  )"
fi

[[ -n "$FIRMWARE_ZIP" ]] || die "no camera firmware zip found under $ASSET_DIR"
[[ -f "$FIRMWARE_ZIP" ]] || die "firmware file not found: $FIRMWARE_ZIP"

BASE="$(basename "$FIRMWARE_ZIP")"
REMOTE_ZIP="${UPGRADE_DIR}/${BASE}"

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: selected firmware: $FIRMWARE_ZIP"
echo "INFO: pushing to: $REMOTE_ZIP"

remote "mkdir -p '$UPGRADE_DIR' && rm -f '$REMOTE_ZIP'"
upload_with_progress "$FIRMWARE_ZIP" "$REMOTE_ZIP"

echo "INFO: writing upgrade command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'upgrade %s\\n' '$REMOTE_ZIP' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "OK: camera upgrade command sent (no confirm, no version gate)"
echo "INFO: filter device logs with: make logs GREP=CameraProgram"
