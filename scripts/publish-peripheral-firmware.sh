#!/usr/bin/env bash
# Publish signed control-board or camera firmware + release.json to R2.
# Usage:
#   make publish-control-board-firmware
#   make publish-camera-firmware
#   FIRMWARE_BIN=… make publish-control-board-firmware-only
#   FIRMWARE_ZIP=… make publish-camera-firmware-only
#
# Always writes release.json (no staging / -beta).
# Auth/API base match make publish (cloud_api_base + publish token).
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

CHANNEL="${1:-}"
ONLY="${2:-0}"
case "$CHANNEL" in
control-board | camera) ;;
*)
	die "usage: $0 control-board|camera [only=0|1]"
	;;
esac

command -v python3 >/dev/null 2>&1 || die "python3 not found"

if [[ -n "${PUBLISH_ARTIFACT:-}" ]]; then
	ARTIFACT_ROOT="${PUBLISH_ARTIFACT}"
elif [[ "$APP" == *_hmi ]]; then
	ARTIFACT_ROOT="${APP//_/-}"
else
	die "APP='$APP' is not an *_hmi product; refuse publish (or set PUBLISH_ARTIFACT=…)"
fi
ARTIFACT="${ARTIFACT_ROOT}/${CHANNEL}"

case "$CHANNEL" in
control-board)
	ASSET_DIR="$APP_DIR/assets/firmware/control-board"
	export ASSET_DIR
	if [[ -z "${FIRMWARE_BIN:-}" ]]; then
		[[ "$ONLY" == "1" ]] && die "FIRMWARE_BIN required for publish-control-board-firmware-only"
		FIRMWARE_BIN="$(
			python3 - <<'PY'
import glob, os, re
asset_dir = os.environ["ASSET_DIR"]
pat = re.compile(r"^LSW01H(?P<hw>\d{4})S(?P<sw>\d{4})\.bin$", re.I)
best = None
for p in glob.glob(os.path.join(asset_dir, "LSW01H*.bin")):
    name = os.path.basename(p)
    m = pat.match(name)
    if not m:
        continue
    cand = (int(m.group("sw")), int(m.group("hw")), p)
    if best is None or (cand[0], cand[1]) > (best[0], best[1]):
        best = cand
print("" if best is None else best[2])
PY
		)"
	fi
	PACKAGE="${FIRMWARE_BIN:-}"
	[[ -n "$PACKAGE" ]] || die "no control-board firmware under $ASSET_DIR"
	CONTENT_TYPE="application/octet-stream"
	# Channel version = software integer from LSW01H####S####.bin → manifest "1017" (no "v" prefix).
	# filename remains SoT for HW match.
	PACK_VERSION="$(
		python3 -c '
import re, sys
name = sys.argv[1]
m = re.match(r"^LSW01H\d{4}S(\d{4})\.bin$", name, re.I)
if not m:
    raise SystemExit(f"unparsable control-board firmware name: {name}")
print(int(m.group(1)))
' "$(basename "$PACKAGE")"
	)" || die "control-board firmware basename must match LSW01H####S####.bin"
	VERSION_PREFIX=""
	;;
camera)
	ASSET_DIR="$APP_DIR/assets/firmware/camera"
	export ASSET_DIR
	if [[ -z "${FIRMWARE_ZIP:-}" ]]; then
		[[ "$ONLY" == "1" ]] && die "FIRMWARE_ZIP required for publish-camera-firmware-only"
		FIRMWARE_ZIP="$(
			python3 - <<'PY'
import glob, os, re
asset_dir = os.environ["ASSET_DIR"]
pat = re.compile(
    r"^(?P<model>[A-Za-z0-9]+)-v(?P<maj>\d+)\.(?P<min>\d+)\.(?P<patch>\d+) "
    r"build(?P<build>\d{8})\.zip$",
    re.I,
)
best = None
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
	PACKAGE="${FIRMWARE_ZIP:-}"
	[[ -n "$PACKAGE" ]] || die "no camera firmware under $ASSET_DIR"
	CONTENT_TYPE="application/zip"
	base="$(basename "$PACKAGE" .zip)"
	# Channel version = SemVer only with leading v: "v1.0.7"
	# (build stays in filename SoT: MODEL-v1.0.7 buildYYYYMMDD.zip).
	PACK_VERSION="$(
		python3 -c '
import re, sys
name = sys.argv[1]
m = re.match(r"^[A-Za-z0-9]+-v(\d+\.\d+\.\d+) build(\d{8})$", name, re.I)
if not m:
    raise SystemExit(f"unparsable camera firmware name: {name}")
print(m.group(1))
' "$base"
	)" || die "camera firmware basename must match MODEL-vX.Y.Z buildYYYYMMDD.zip"
	VERSION_PREFIX="v"
	;;
esac

[[ -f "$PACKAGE" ]] || die "firmware file not found: $PACKAGE"
PACK_NAME="$(basename "$PACKAGE")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lws-peripheral-publish.XXXXXX")"
WORK_PKG="$WORK_DIR/$PACK_NAME"
WORK_SIG="$WORK_DIR/${PACK_NAME}.sig"
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

echo "INFO: publish APP=$APP artifact=$ARTIFACT file=$PACK_NAME version=${VERSION_PREFIX}${PACK_VERSION} manifest=release.json"
echo "INFO: package=$PACKAGE"
echo "INFO: api_base=$BASE"
echo "NOTE: sibling api-server may need R2 key allowlist for ${ARTIFACT}/*"

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
