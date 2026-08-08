#!/usr/bin/env bash
# Package the selected APP overlay install tree as v{semver}.tar.gz for
# upgrade-app / publish-app. Tree matches make build-app → /opt/hmi layout.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve

die() { echo "ERROR: $*" >&2; exit 1; }

usage() {
	cat <<EOF
Usage: make package-app | bash scripts/package-app.sh

Packages OVERLAY_APP (\$OVERLAY_APP) into:
  output/firmware/<APP>/v{semver}.tar.gz

Prereq: APP=\$APP make build-app
Env: APP= (default lws_hmi), APP_PACKAGE= override output path
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

[[ -d "$OVERLAY_APP" ]] || die "missing overlay app tree: $OVERLAY_APP (run: make build-app)"
[[ -f "$OVERLAY_APP/lib/libapp.so" ]] || die "missing $OVERLAY_APP/lib/libapp.so (run: make build-app)"
[[ -d "$OVERLAY_APP/data/flutter_assets" ]] || die "missing $OVERLAY_APP/data/flutter_assets (run: make build-app)"

PUBSPEC="${APP_DIR}/pubspec.yaml"
[[ -f "$PUBSPEC" ]] || die "missing $PUBSPEC"
VERSION_LINE="$(sed -n 's/^[[:space:]]*version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$PUBSPEC" | sed -n '1p')"
[[ -n "$VERSION_LINE" ]] || die "failed to parse version: from $PUBSPEC"
SEMVER="${VERSION_LINE%%+*}"
[[ "$SEMVER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "unparsable semver in $PUBSPEC (got '$VERSION_LINE')"

OUT_DIR="${APP_FIRMWARE_DIR:-$ROOT/output/firmware/$APP}"
mkdir -p "$OUT_DIR"
PACK_NAME="v${SEMVER}.tar.gz"
OUT="${APP_PACKAGE:-$OUT_DIR/$PACK_NAME}"

# Top-level entries become /opt/hmi/{lib,data,bin,...} after extract.
# Skip macOS AppleDouble / Finder junk (also set COPYFILE_DISABLE for BSD tar).
# Skip empty .gitkeep placeholders: current-board install uses DdWriter which
# rejects zero-byte sources; dirs with real assets do not need them.
export COPYFILE_DISABLE=1
tar \
	--exclude='._*' \
	--exclude='.DS_Store' \
	--exclude='.gitkeep' \
	-C "$OVERLAY_APP" -czf "$OUT" .
echo "OK: packaged $OUT"
printf '%s\n' "$OUT"
