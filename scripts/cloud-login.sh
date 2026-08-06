#!/usr/bin/env bash
# Log in to sibling api-server (POST /v1/login) and persist access_token.
# Usage:
#   make login
#   CLOUD_ACCOUNT=ops@example.com CLOUD_PASSWORD=… make login
#   CLOUD_API_BASE=https://api-test.lasercyber.workers.dev make login   # test override
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLOUD_REPO_ROOT="$ROOT"
# shellcheck source=scripts/cloud-credentials.sh
source "$ROOT/scripts/cloud-credentials.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage:
  make login
  CLOUD_ACCOUNT=<user|email> CLOUD_PASSWORD=<secret> make login

Calls POST /v1/login on CLOUD_API_BASE (default https://api-prod.lasercyber.workers.dev)
and writes access_token to output/cloud/credentials.json (gitignored, mode 600).
Password is never persisted. Do not put CLOUD_PASSWORD in a tracked file.

Override to test: CLOUD_API_BASE=https://api-test.lasercyber.workers.dev make login
Token is used by: make register-device, make publish (fallback after PUBLISH_API_TOKEN).
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

command -v curl >/dev/null 2>&1 || die "curl not found"
command -v python3 >/dev/null 2>&1 || die "python3 not found"

ACCOUNT="${CLOUD_ACCOUNT:-}"
PASSWORD="${CLOUD_PASSWORD:-}"

if [[ -z "$ACCOUNT" ]]; then
	if [[ -t 0 ]]; then
		printf 'Account: '
		IFS= read -r ACCOUNT || true
	else
		die "CLOUD_ACCOUNT unset and stdin is not a TTY (see: make login -h)"
	fi
fi
[[ -n "$ACCOUNT" ]] || die "account is required"

if [[ -z "$PASSWORD" ]]; then
	if [[ -t 0 ]]; then
		printf 'Password: '
		IFS= read -r -s PASSWORD || true
		printf '\n'
	else
		die "CLOUD_PASSWORD unset and stdin is not a TTY (see: make login -h)"
	fi
fi
[[ -n "$PASSWORD" ]] || die "password is required"

BASE="$(cloud_api_base)"
echo "INFO: logging in at ${BASE}/v1/login (account=${ACCOUNT})"

# Build JSON body without putting password on the process argv of python -c via shell.
BODY="$(
	CLOUD_LOGIN_ACCOUNT="$ACCOUNT" CLOUD_LOGIN_PASSWORD="$PASSWORD" python3 - <<'PY'
import json, os
print(json.dumps({
    "account": os.environ["CLOUD_LOGIN_ACCOUNT"],
    "password": os.environ["CLOUD_LOGIN_PASSWORD"],
}, ensure_ascii=False))
PY
)"

# Clear password from shell as soon as body is built.
PASSWORD=""
unset PASSWORD
unset CLOUD_PASSWORD || true

cloud_http_json POST "/v1/login" "$BODY" || die "login HTTP request failed"
STATUS="${CLOUD_HTTP_STATUS:-0}"
RESP="${CLOUD_HTTP_BODY:-}"

PARSE="$(
	CLOUD_LOGIN_RESP="$RESP" CLOUD_LOGIN_HTTP="$STATUS" python3 - <<'PY'
import json, os, sys

raw = os.environ.get("CLOUD_LOGIN_RESP") or ""
http = int(os.environ.get("CLOUD_LOGIN_HTTP") or "0")
try:
    obj = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    print(f"ERROR: non-JSON login response (HTTP {http}): {raw[:200]}", file=sys.stderr)
    sys.exit(2)

success = obj.get("success") is True or (isinstance(obj.get("code"), int) and 200 <= obj["code"] < 300 and obj.get("data"))
data = obj.get("data") if isinstance(obj.get("data"), dict) else None
token = (data or {}).get("access_token") if data else None
msg = obj.get("message") or ""
err = obj.get("error_code") or obj.get("errorCode") or ""
code = obj.get("code")

if http in (401, 403, 404) or not success or not (isinstance(token, str) and token.strip()):
    parts = [f"login failed HTTP {http}"]
    if code is not None:
        parts.append(f"code={code}")
    if err:
        parts.append(str(err))
    if msg:
        parts.append(str(msg))
    print("ERROR: " + " — ".join(parts), file=sys.stderr)
    sys.exit(1)

account = data.get("email") or data.get("username") or data.get("user_name") or ""
username = data.get("username") or data.get("user_name") or ""
role = data.get("role")
# Emit: token\taccount\tusername\trole
print("\t".join([
    token.strip(),
    str(account or ""),
    str(username or ""),
    "" if role is None else str(role),
]))
PY
)" || {
	# Do not clobber existing credentials on failure
	exit 1
}

IFS=$'\t' read -r TOKEN OUT_ACCOUNT OUT_USERNAME OUT_ROLE <<<"$PARSE"
[[ -n "$TOKEN" ]] || die "login succeeded but access_token empty"

CLOUD_WRITE_ACCESS_TOKEN="$TOKEN" \
	CLOUD_WRITE_ACCOUNT="${OUT_ACCOUNT:-$ACCOUNT}" \
	CLOUD_WRITE_USERNAME="$OUT_USERNAME" \
	CLOUD_WRITE_ROLE="$OUT_ROLE" \
	CLOUD_WRITE_API_BASE="$BASE" \
	cloud_write_credentials >/dev/null

CREDS="$(cloud_credentials_path)"
TOKEN_TAIL="${TOKEN: -8}"
ROLE_NOTE=""
[[ -n "$OUT_ROLE" ]] && ROLE_NOTE=" role=${OUT_ROLE}"
echo "OK: logged in as ${OUT_ACCOUNT:-$ACCOUNT}${ROLE_NOTE}"
echo "OK: credentials → ${CREDS} (token …${TOKEN_TAIL})"
