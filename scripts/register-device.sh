#!/usr/bin/env bash
# Register the selected board with api-server admin devices API.
# Usage:
#   make register-device
#   SN=… make register-device
#   IP=… make register-device
#
# SN=/IP= select the board only (same as push-app / write-identity).
# Product sn + model always come from on-board read-identity (Vendor Storage).
# Prereq: make login (or CLOUD_ACCESS_TOKEN=…). Board needs make write-identity first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLOUD_REPO_ROOT="$ROOT"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"
# shellcheck source=scripts/cloud-credentials.sh
source "$ROOT/scripts/cloud-credentials.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage:
  make register-device
  SN=<sn> make register-device
  IP=<addr> make register-device

Select the board with SN= / IP= (same rules as push-app / write-identity), SSH
read product sn + model via read-identity, then POST /v1/admin/devices with the
login JWT.

Do not pass PRODUCT_SN= / MODEL= here — provision identity with make write-identity.
Prereq: make login (operator/admin role). Empty identity → make write-identity.
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

# Refuse identity payload overrides on the Make command line only (PRODUCT_SN in
# .env for write-identity must not break register-device).
for o in "$@"; do
	[[ "${o}" == *=* ]] || continue
	key="${o%%=*}"
	case "$key" in
	PRODUCT_SN | MODEL | BRAND)
		die "$key= is not accepted by register-device — use SN=/IP= to select the board; provision identity with: make write-identity BRAND=… MODEL=… PRODUCT_SN=…"
		;;
	esac
done

command -v curl >/dev/null 2>&1 || die "curl not found"
command -v python3 >/dev/null 2>&1 || die "python3 not found"
require_ssh_identity "$ROOT"

# Fail before SSH if no token
TOKEN="$(cloud_resolve_access_token)" || exit 1
BASE="$(cloud_api_base)"

# SN=/IP= (and USB-SSH defaults) applied inside usb_ssh_session_prepare → device-target
usb_ssh_session_prepare "$ROOT"

if usb_ssh_session_is_remote; then
	echo "SSH register-device: target=$TARGET_USER@$TARGET_ADDR"
else
	echo "USB-SSH register-device: iface=$IFACE target=$TARGET_USER@$TARGET_ADDR"
fi

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

read_identity_field() {
	local field="$1"
	remote "/usr/bin/read-identity ${field} 2>/dev/null || /usr/libexec/board/read-product-identity.sh ${field} 2>/dev/null || true" \
		| tr -d '\r' \
		| sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

echo "INFO: reading device sn + model from Vendor Storage (read-identity)"
DEVICE_SN="$(read_identity_field sn)"
DEVICE_MODEL="$(read_identity_field model)"

[[ -n "$DEVICE_SN" ]] || die "device sn empty/missing — run: make write-identity BRAND=… MODEL=… PRODUCT_SN=…"
[[ -n "$DEVICE_MODEL" ]] || die "device model empty/missing — run: make write-identity BRAND=… MODEL=… PRODUCT_SN=…"

echo "INFO: registering sn=${DEVICE_SN} model=${DEVICE_MODEL} at ${BASE}/v1/admin/devices"

BODY="$(
	CLOUD_REG_SN="$DEVICE_SN" CLOUD_REG_MODEL="$DEVICE_MODEL" python3 - <<'PY'
import json, os
print(json.dumps({
    "sn": os.environ["CLOUD_REG_SN"],
    "model": os.environ["CLOUD_REG_MODEL"],
}, ensure_ascii=False))
PY
)"

cloud_http_json POST "/v1/admin/devices" "$BODY" "$TOKEN" || die "register HTTP request failed"
STATUS="${CLOUD_HTTP_STATUS:-0}"
RESP="${CLOUD_HTTP_BODY:-}"

CLOUD_REG_RESP="$RESP" CLOUD_REG_HTTP="$STATUS" python3 - <<'PY'
import json, os, sys

raw = os.environ.get("CLOUD_REG_RESP") or ""
http = int(os.environ.get("CLOUD_REG_HTTP") or "0")
try:
    obj = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    print(f"ERROR: non-JSON register response (HTTP {http}): {raw[:200]}", file=sys.stderr)
    sys.exit(2)

success = obj.get("success") is True
data = obj.get("data") if isinstance(obj.get("data"), dict) else None
msg = obj.get("message") or ""
err = obj.get("error_code") or obj.get("errorCode") or ""
code = obj.get("code")

def fail(extra: str) -> None:
    parts = [extra]
    if code is not None:
        parts.append(f"code={code}")
    if err:
        parts.append(str(err))
    if msg:
        parts.append(str(msg))
    print("ERROR: " + " — ".join(parts), file=sys.stderr)
    sys.exit(1)

if http == 401:
    fail("register unauthorized (HTTP 401) — run: make login")
if http == 403:
    fail("register forbidden (HTTP 403) — need operator/admin role (3/4/9)")
if http == 409:
    fail("device already registered (HTTP 409)")
if http >= 400 or not success or data is None:
    fail(f"register failed HTTP {http}")

sn = data.get("sn") or ""
model = data.get("model") or ""
device_id = data.get("device_id") or ""
activated = data.get("is_activated")
print(f"OK: registered sn={sn} model={model} device_id={device_id} is_activated={activated}")
PY
