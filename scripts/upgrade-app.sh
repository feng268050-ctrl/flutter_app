#!/usr/bin/env bash
# Sign + host-HTTP serve HMI app tar.gz; device downloads, verifies, installs
# to /opt/hmi and restarts hmi.service (make upgrade-app / push-app alias).
#
# Device-side: app watches `/run/hmi/upgrade-app.cmd` for:
#   download <http://host:port/vX.Y.Z.tar.gz>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/peripheral-ota-http.sh
source "$ROOT/scripts/peripheral-ota-http.sh"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve

usage() {
	cat <<EOF
Usage: make upgrade-app [APP_PACKAGE=/abs/path/to/vX.Y.Z.tar.gz]

By default packages the current overlay app tree (make pack-app) then
signs with OTA_SIGNING_KEY (default keys/ota/ed25519.pem), serves over
ephemeral host HTTP, and writes:
  /run/hmi/upgrade-app.cmd  →  download <url>

Env: APP= / APP_PACKAGE= / OTA_HTTP_HOST / OTA_HTTP_PORT / OTA_SIGNING_KEY / SN= / IP=

Prereq: HMI app is running (hmi.service) so the command watcher can react.
  Prefer: make build-app && make upgrade-app
EOF
}

die() { peripheral_ota_die "$@"; }

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

CMD_PATH="/run/hmi/upgrade-app.cmd"

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

if [[ -z "${APP_PACKAGE:-}" ]]; then
	chmod +x "$ROOT/scripts/pack-app.sh"
	APP_PACKAGE="$(APP="$APP" bash "$ROOT/scripts/pack-app.sh" | tail -n1)"
fi

[[ -n "$APP_PACKAGE" ]] || die "APP_PACKAGE empty"
[[ -f "$APP_PACKAGE" ]] || die "app package not found: $APP_PACKAGE"
[[ "$APP_PACKAGE" == *.tar.gz ]] || die "expected .tar.gz package: $APP_PACKAGE"

BASE="$(basename "$APP_PACKAGE")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-app-ota.XXXXXX")"
WORK_PKG="$WORK_DIR/$BASE"
WORK_SIG="$WORK_DIR/${BASE}.sig"
cp -f "$APP_PACKAGE" "$WORK_PKG"

cleanup() {
	peripheral_ota_stop_http_server
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: selected package: $APP_PACKAGE"
peripheral_ota_sign "$WORK_PKG" "$WORK_SIG"

peripheral_ota_resolve_http_bind
echo "INFO: serving on $OTA_HTTP_BIND (device will HTTP GET)..."
peripheral_ota_start_http_server "$WORK_PKG" "$WORK_SIG" "$BASE"
echo "INFO: package_url=$PACKAGE_URL"

echo "INFO: writing download command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'download %s\\n' '$PACKAGE_URL' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "INFO: waiting for device HTTP GET of tar.gz + .sig..."
peripheral_ota_wait_transfer_complete 600

peripheral_ota_stop_http_server
trap - EXIT
rm -rf "$WORK_DIR"

echo "OK: transfer complete — device will verify, install /opt/hmi, and restart hmi.service"
echo "INFO: filter device logs with: make logs GREP=UpgradeApp"
