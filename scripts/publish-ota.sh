#!/usr/bin/env bash
# Publish signed OTA tar.gz (+ .sig) + release.json to R2 via cloud presigned URL.
# Usage:
#   make publish / make publish-only
#   APP=lws_hmi make publish-only
#   PUBLISH_ARTIFACT=lws-hmi make publish-only   # escape hatch for non-*_hmi APP
#
# Always writes release.json with plain pubspec semver (no staging / -beta / RELEASE=).
#
# Inherits ota-package layout:
#   output/firmware/<APP>/ota-package.tar.gz
#   output/firmware/<APP>/ota-package.tar.gz.sig
# Env: OEM_ONLY / OTA_SIGNING_KEY / REQUIRE_OTA_SIG apply only to make ota-package (publish prereq).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLOUD_REPO_ROOT="$ROOT"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve
# shellcheck source=scripts/cloud-credentials.sh
source "$ROOT/scripts/cloud-credentials.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<'EOF'
Usage:
  make publish                 # ota-package then upload release.json
  make publish-only            # upload existing ota-package.tar.gz + .sig
  APP=<id>_hmi make publish    # R2 prefix = APP with _ → - (default lws_hmi → lws-hmi)
  PUBLISH_ARTIFACT=<slug>      # override artifact prefix (also allows non-*_hmi APP)

Release-only: always {artifact}/release.json and v{semver}.tar.gz (no staging / -beta).
Do not set RELEASE= (removed).

Uploads via GET {CLOUD_API_BASE}/v1/storage/r2/presigned-url then HTTP PUT to R2
(same default API base as make login / register-device: api-prod).
Auth: PUBLISH_API_TOKEN → CLOUD_ACCESS_TOKEN → make login credentials.json
Channel manifest: version, filename, published_at, url (no sha512; integrity = .sig).
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

command -v python3 >/dev/null 2>&1 || die "python3 not found"

# RELEASE channel toggle removed — always release.json.
if [[ -n "${RELEASE+x}" ]]; then
	die "RELEASE is removed; publish always writes release.json (unset RELEASE and run: make publish)"
fi

ARCHIVE_NAME="${OTA_PACKAGE_NAME:-ota-package.tar.gz}"
ARCHIVE="${APP_FIRMWARE_DIR}/${ARCHIVE_NAME}"
SIG="${ARCHIVE}.sig"

# Artifact slug: APP kebab, or PUBLISH_ARTIFACT escape hatch.
if [[ -n "${PUBLISH_ARTIFACT:-}" ]]; then
	ARTIFACT="${PUBLISH_ARTIFACT}"
elif [[ "$APP" == *_hmi ]]; then
	ARTIFACT="${APP//_/-}"
else
	die "APP='$APP' is not an *_hmi product; refuse publish (or set PUBLISH_ARTIFACT=…)"
fi
[[ -n "$ARTIFACT" ]] || die "empty artifact slug"

[[ -f "$ARCHIVE" ]] || die "OTA archive missing: $ARCHIVE (run: make ota-package)"
[[ -f "$SIG" ]] || die "OTA signature missing: $SIG (run: OTA_SIGNING_KEY=… REQUIRE_OTA_SIG=1 make ota-package)"

PUBSPEC="${APP_DIR}/pubspec.yaml"
[[ -f "$PUBSPEC" ]] || die "missing $PUBSPEC"
VERSION_LINE="$(sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$PUBSPEC" | sed -n '1p')"
[[ -n "$VERSION_LINE" ]] || die "failed to parse version: from $PUBSPEC"
SEMVER="${VERSION_LINE%%+*}"
[[ "$SEMVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "unparsable semver in $PUBSPEC (got '$VERSION_LINE')"

PACK_VERSION="$SEMVER"
MANIFEST_NAME="release.json"
PACK_NAME="v${PACK_VERSION}.tar.gz"

TOKEN="$(cloud_resolve_publish_token)" || exit 1
BASE="$(cloud_api_base)"

echo "INFO: publish APP=$APP artifact=$ARTIFACT version=v${PACK_VERSION} manifest=$MANIFEST_NAME"
echo "INFO: archive=$ARCHIVE"
echo "INFO: api_base=$BASE"

python3 "$ROOT/scripts/publish_ota.py" \
	--base-url "$BASE" \
	--token "$TOKEN" \
	--artifact "$ARTIFACT" \
	--archive-path "$ARCHIVE" \
	--sig-path "$SIG" \
	--pack-name "$PACK_NAME" \
	--pack-version "$PACK_VERSION" \
	--manifest-name "$MANIFEST_NAME"
