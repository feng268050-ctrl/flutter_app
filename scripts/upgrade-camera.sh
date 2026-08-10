#!/usr/bin/env bash
# Sign + host-HTTP serve camera firmware ZIP; device downloads, verifies, applies
# (no confirm, no version gate; operator `make upgrade-camera` helper).
#
# Device-side: app watches `/run/hmi/upgrade-camera.cmd` for:
#   download <http://host:port/<zip>>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/peripheral-ota-http.sh
source "$ROOT/scripts/peripheral-ota-http.sh"

usage() {
  cat <<EOF
Usage: make upgrade-camera [FIRMWARE_ZIP=/abs/path/to/MODEL-vX.Y.Z\\ buildYYYYMMDD.zip]

By default picks the newest SemVer then build under:
  app/lws_hmi/assets/firmware/camera/*.zip

Signs with OTA_SIGNING_KEY (default keys/ota/ed25519.pem), serves over
ephemeral host HTTP, and writes:
  /run/hmi/upgrade-camera.cmd  →  download <url>

Env: OTA_HTTP_HOST / OTA_HTTP_PORT / OTA_SIGNING_KEY / SN= / IP=

Prereq: HMI app is running (hmi.service) so the command watcher can react.
EOF
}

die() { peripheral_ota_die "$@"; }

remote() {
  usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

ASSET_DIR="$ROOT/app/lws_hmi/assets/firmware/camera"
CMD_PATH="/run/hmi/upgrade-camera.cmd"
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
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-cam-fw.XXXXXX")"
WORK_ZIP="$WORK_DIR/$BASE"
WORK_SIG="$WORK_DIR/${BASE}.sig"
cp -f "$FIRMWARE_ZIP" "$WORK_ZIP"

cleanup() {
  peripheral_ota_stop_http_server
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: selected firmware: $FIRMWARE_ZIP"
peripheral_ota_sign "$WORK_ZIP" "$WORK_SIG"

peripheral_ota_resolve_http_bind
echo "INFO: serving on $OTA_HTTP_BIND (device will HTTP GET)..."
peripheral_ota_start_http_server "$WORK_ZIP" "$WORK_SIG" "$BASE"
echo "INFO: package_url=$PACKAGE_URL"

echo "INFO: writing download command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'download %s\\n' '$PACKAGE_URL' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "INFO: waiting for device HTTP GET of zip + .sig..."
peripheral_ota_wait_transfer_complete 600

peripheral_ota_stop_http_server
trap - EXIT
rm -rf "$WORK_DIR"

echo "OK: transfer complete — device will verify and CGI-flash (no confirm, no version gate)"
echo "INFO: filter device logs with: make logs GREP=CameraProgram"
