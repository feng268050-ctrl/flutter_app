#!/usr/bin/env bash
# Publish signed OTA tar.gz (+ .sig) + channel manifest to R2 via cloud presigned URL.
# Usage:
#   make publish / make publish-only
#   APP=lws_hmi RELEASE=1 make publish-only
#   PUBLISH_ARTIFACT=lws-hmi make publish-only   # escape hatch for non-*_hmi APP
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
  make publish                 # ota-package then upload
  make publish-only            # upload existing ota-package.tar.gz + .sig
  RELEASE=1 make publish       # release.json (no -beta); default staging.json + -beta
  APP=<id>_hmi make publish    # R2 prefix = APP with _ → - (default lws_hmi → lws-hmi)
  PUBLISH_ARTIFACT=<slug>      # override artifact prefix (also allows non-*_hmi APP)

Uploads via GET {CLOUD_API_BASE}/v1/storage/r2/presigned-url then HTTP PUT to R2
(same default API base as make login / register-device: api-prod).
Auth: PUBLISH_API_TOKEN → CLOUD_ACCESS_TOKEN → make login credentials.json
Channel manifest: version, filename, published_at, url (no sha512; integrity = .sig).
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

command -v python3 >/dev/null 2>&1 || die "python3 not found"

ARCHIVE_NAME="${OTA_PACKAGE_NAME:-ota-package.tar.gz}"
ARCHIVE="${APP_FIRMWARE_DIR}/${ARCHIVE_NAME}"
SIG="${ARCHIVE}.sig"

RELEASE="${RELEASE:-0}"
case "$RELEASE" in
0 | 1) ;;
*) die "RELEASE must be 0 or 1 (got: $RELEASE)" ;;
esac

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

if [[ "$RELEASE" == "1" ]]; then
	PACK_VERSION="$SEMVER"
	MANIFEST_NAME="release.json"
else
	PACK_VERSION="${SEMVER}-beta"
	MANIFEST_NAME="staging.json"
fi

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
