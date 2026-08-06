#!/usr/bin/env bash
# Shared host helpers for api-server login credentials (make login / register-device / publish).
# Source from other scripts:  source "$ROOT/scripts/cloud-credentials.sh"
#
# Env:
#   CLOUD_API_BASE       (default https://api-prod.lasercyber.workers.dev)
#   CLOUD_ACCESS_TOKEN   explicit Bearer override (wins over credentials file)
#   PUBLISH_API_TOKEN    publish-only override (use cloud_resolve_publish_token)
#   CLOUD_CREDENTIALS    override credentials path (default $ROOT/output/cloud/credentials.json)

# shellcheck disable=SC2034

cloud_default_api_base() {
	echo "https://api-prod.lasercyber.workers.dev"
}

cloud_credentials_path() {
	local root="${CLOUD_REPO_ROOT:-}"
	if [[ -z "$root" ]]; then
		root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	fi
	if [[ -n "${CLOUD_CREDENTIALS:-}" ]]; then
		echo "$CLOUD_CREDENTIALS"
		return
	fi
	echo "$root/output/cloud/credentials.json"
}

cloud_api_base() {
	local base="${CLOUD_API_BASE:-$(cloud_default_api_base)}"
	# Strip trailing slashes
	base="${base%/}"
	while [[ "$base" == */ ]]; do
		base="${base%/}"
	done
	echo "$base"
}

# Write credentials JSON atomically; chmod 600. Args via env:
#   CLOUD_WRITE_ACCESS_TOKEN (required), CLOUD_WRITE_ACCOUNT, CLOUD_WRITE_ROLE,
#   CLOUD_WRITE_API_BASE, CLOUD_WRITE_USERNAME
cloud_write_credentials() {
	local path dir tmp token
	token="${CLOUD_WRITE_ACCESS_TOKEN:-}"
	[[ -n "$token" ]] || {
		echo "ERROR: cloud_write_credentials: missing access_token" >&2
		return 1
	}
	path="$(cloud_credentials_path)"
	dir="$(dirname "$path")"
	mkdir -p "$dir"
	tmp="$(mktemp "${dir}/.credentials.XXXXXX")"
	CLOUD_WRITE_PATH="$path" CLOUD_WRITE_TMP="$tmp" \
		CLOUD_WRITE_ACCESS_TOKEN="$token" \
		CLOUD_WRITE_ACCOUNT="${CLOUD_WRITE_ACCOUNT:-}" \
		CLOUD_WRITE_USERNAME="${CLOUD_WRITE_USERNAME:-}" \
		CLOUD_WRITE_ROLE="${CLOUD_WRITE_ROLE:-}" \
		CLOUD_WRITE_API_BASE="${CLOUD_WRITE_API_BASE:-$(cloud_api_base)}" \
		python3 - <<'PY'
import json, os, time
from pathlib import Path

out = {
    "access_token": os.environ["CLOUD_WRITE_ACCESS_TOKEN"],
    "api_base": os.environ.get("CLOUD_WRITE_API_BASE") or "",
    "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
}
for key, env in (
    ("account", "CLOUD_WRITE_ACCOUNT"),
    ("username", "CLOUD_WRITE_USERNAME"),
    ("role", "CLOUD_WRITE_ROLE"),
):
    val = os.environ.get(env) or ""
    if val != "":
        if key == "role":
            try:
                out[key] = int(val)
            except ValueError:
                out[key] = val
        else:
            out[key] = val

tmp = Path(os.environ["CLOUD_WRITE_TMP"])
path = Path(os.environ["CLOUD_WRITE_PATH"])
tmp.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
tmp.replace(path)
os.chmod(path, 0o600)
print(str(path))
PY
}

# Print access_token from credentials file, or empty if missing/invalid.
cloud_read_credentials_token() {
	local path
	path="$(cloud_credentials_path)"
	[[ -f "$path" ]] || return 0
	CLOUD_CREDENTIALS_PATH="$path" python3 - <<'PY'
import json, os, sys
path = os.environ["CLOUD_CREDENTIALS_PATH"]
try:
    data = json.loads(open(path, encoding="utf-8").read())
except Exception:
    sys.exit(0)
token = data.get("access_token") if isinstance(data, dict) else None
if isinstance(token, str) and token.strip():
    print(token.strip(), end="")
PY
}

# Resolve Bearer for register-device / generic cloud JWT APIs.
# Priority: CLOUD_ACCESS_TOKEN → credentials file → fail.
# Prints token to stdout; dies (exit 1) with make login hint on failure when die_on_missing=1 (default).
cloud_resolve_access_token() {
	local die_on_missing="${1:-1}"
	local token=""
	if [[ -n "${CLOUD_ACCESS_TOKEN:-}" ]]; then
		token="$CLOUD_ACCESS_TOKEN"
	else
		token="$(cloud_read_credentials_token || true)"
	fi
	if [[ -z "$token" ]]; then
		if [[ "$die_on_missing" == "1" ]]; then
			echo "ERROR: no cloud access token — run: make login" >&2
			echo "  (or set CLOUD_ACCESS_TOKEN=…)" >&2
			return 1
		fi
		return 0
	fi
	printf '%s' "$token"
}

# Resolve Bearer for make publish upload.
# Priority: PUBLISH_API_TOKEN → CLOUD_ACCESS_TOKEN → credentials file → fail.
cloud_resolve_publish_token() {
	local die_on_missing="${1:-1}"
	local token=""
	if [[ -n "${PUBLISH_API_TOKEN:-}" ]]; then
		token="$PUBLISH_API_TOKEN"
	elif [[ -n "${CLOUD_ACCESS_TOKEN:-}" ]]; then
		token="$CLOUD_ACCESS_TOKEN"
	else
		token="$(cloud_read_credentials_token || true)"
	fi
	if [[ -z "$token" ]]; then
		if [[ "$die_on_missing" == "1" ]]; then
			echo "ERROR: no publish/cloud token — set PUBLISH_API_TOKEN=… (static upload) or run: make login" >&2
			return 1
		fi
		return 0
	fi
	printf '%s' "$token"
}

# POST/PUT JSON to api-server.
# Args: METHOD path body_json [bearer_token]
# Sets globals (caller must NOT wrap in $() — that loses the status):
#   CLOUD_HTTP_STATUS  numeric HTTP status
#   CLOUD_HTTP_BODY    response body text
cloud_http_json() {
	local method="$1"
	local path="$2"
	local body="${3:-}"
	local bearer="${4:-}"
	local url base tmp_hdr tmp_body http_code
	base="$(cloud_api_base)"
	url="${base}${path}"
	tmp_hdr="$(mktemp)"
	tmp_body="$(mktemp)"

	local -a curl_args=(
		-sS
		-X "$method"
		-H "Content-Type: application/json"
		-H "Accept: application/json"
		-D "$tmp_hdr"
		-o "$tmp_body"
		-w "%{http_code}"
	)
	if [[ -n "$bearer" ]]; then
		curl_args+=(-H "Authorization: Bearer ${bearer}")
	fi
	if [[ -n "$body" ]]; then
		curl_args+=(--data-binary "$body")
	fi
	curl_args+=("$url")

	http_code="$(curl "${curl_args[@]}")" || {
		rm -f "$tmp_hdr" "$tmp_body"
		echo "ERROR: curl failed talking to $url" >&2
		CLOUD_HTTP_STATUS="0"
		CLOUD_HTTP_BODY=""
		export CLOUD_HTTP_STATUS CLOUD_HTTP_BODY
		return 1
	}
	CLOUD_HTTP_STATUS="$http_code"
	CLOUD_HTTP_BODY="$(cat "$tmp_body")"
	export CLOUD_HTTP_STATUS CLOUD_HTTP_BODY
	rm -f "$tmp_hdr" "$tmp_body"
	return 0
}
