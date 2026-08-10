#!/usr/bin/env bash
# Publish signed HMI app tar.gz (+ .sig) + release.json under {artifact}/app/.
# Usage:
#   make publish-app
#   make publish-app-only   # requires existing package + .sig
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLOUD_REPO_ROOT="$ROOT"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve
# shellcheck source=scripts/cloud-credentials.sh
source "$ROOT/scripts/cloud-credentials.sh"
# shellcheck source=scripts/peripheral-ota-http.sh
source "$ROOT/scripts/peripheral-ota-http.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

ONLY="${1:-0}"

command -v python3 >/dev/null 2>&1 || die "python3 not found"

if [[ -n "${RELEASE+x}" ]]; then
	die "RELEASE is removed; publish always writes release.json (unset RELEASE)"
fi

if [[ -n "${PUBLISH_ARTIFACT:-}" ]]; then
	ARTIFACT_ROOT="${PUBLISH_ARTIFACT}"
elif [[ "$APP" == *_hmi ]]; then
	ARTIFACT_ROOT="${APP//_/-}"
else
	die "APP='$APP' is not an *_hmi product; refuse publish (or set PUBLISH_ARTIFACT=…)"
fi
ARTIFACT="${ARTIFACT_ROOT}/app"

PUBSPEC="${APP_DIR}/pubspec.yaml"
[[ -f "$PUBSPEC" ]] || die "missing $PUBSPEC"
VERSION_LINE="$(sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$PUBSPEC" | sed -n '1p')"
[[ -n "$VERSION_LINE" ]] || die "failed to parse version: from $PUBSPEC"
SEMVER="${VERSION_LINE%%+*}"
[[ "$SEMVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "unparsable semver in $PUBSPEC (got '$VERSION_LINE')"
PACK_VERSION="${SEMVER}"
PACK_NAME="v${SEMVER}.tar.gz"
VERSION_PREFIX="v"

OUT_DIR="${APP_PACKAGE_DIR:-$ROOT/output/app/$APP}"
PACKAGE="${APP_PACKAGE:-$OUT_DIR/$PACK_NAME}"

if [[ "$ONLY" != "1" ]]; then
	chmod +x "$ROOT/scripts/pack-app.sh"
	PACKAGE="$(APP="$APP" bash "$ROOT/scripts/pack-app.sh" | tail -n1)"
fi

[[ -f "$PACKAGE" ]] || die "app package missing: $PACKAGE (run: make pack-app / make build-app)"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-publish-app.XXXXXX")"
WORK_PKG="$WORK_DIR/$(basename "$PACKAGE")"
WORK_SIG="$WORK_DIR/$(basename "$PACKAGE").sig"
cp -f "$PACKAGE" "$WORK_PKG"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

if [[ "$ONLY" == "1" && -f "${PACKAGE}.sig" ]]; then
	cp -f "${PACKAGE}.sig" "$WORK_SIG"
else
	peripheral_ota_sign "$WORK_PKG" "$WORK_SIG"
fi
[[ -f "$WORK_SIG" ]] || die "signature missing: $WORK_SIG"

TOKEN="$(cloud_resolve_publish_token)" || exit 1
BASE="$(cloud_api_base)"
CONTENT_TYPE="application/gzip"

echo "INFO: publish APP=$APP artifact=$ARTIFACT file=$PACK_NAME version=${VERSION_PREFIX}${PACK_VERSION} manifest=release.json"
echo "INFO: package=$PACKAGE"
echo "INFO: api_base=$BASE"

python3 "$ROOT/scripts/publish_ota.py" \
	--base-url "$BASE" \
	--token "$TOKEN" \
	--artifact "$ARTIFACT" \
	--archive-path "$WORK_PKG" \
	--sig-path "$WORK_SIG" \
	--pack-name "$PACK_NAME" \
	--pack-version "$PACK_VERSION" \
	--manifest-name release.json \
	--content-type "$CONTENT_TYPE" \
	--version-prefix "$VERSION_PREFIX"

trap - EXIT
rm -rf "$WORK_DIR"
echo "OK: published $ARTIFACT/release.json (${VERSION_PREFIX}${PACK_VERSION})"
