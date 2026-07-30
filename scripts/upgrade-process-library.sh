#!/usr/bin/env bash
# Push a process-library package matched to the device product.ini model and
# force-import it (no same-/older-version gate; operator helper).
#
# Device-side: app watches `/run/hmi/upgrade-process-library.cmd` and imports
# the uploaded package directory.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

ASSET_DIR="$ROOT/app/lws_hmi/assets/process-library"
CMD_PATH="/run/hmi/upgrade-process-library.cmd"
UPGRADE_ROOT="/run/hmi/process-library-upgrade"
PRODUCT_INI="${PRODUCT_INI_PATH:-/var/lib/hal/product.ini}"

usage() {
	cat <<EOF
Usage: make upgrade-process-library [PACKAGE_DIR=/abs/path/to/package]

Reads product model from device $PRODUCT_INI (key model=), selects
  $ASSET_DIR/<Model_With_Underscores>/<newest>.xlsx
converts it to a package, uploads under $UPGRADE_ROOT/, and writes:
  $CMD_PATH

Optional PACKAGE_DIR= skips Excel convert and uploads that directory
(must contain manifest.json).

Prereq: HMI app is running (hmi.service) with the upgrade watcher.
EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

usb_ssh_session_load_env "$ROOT"
usb_ssh_session_select "$ROOT"
usb_ssh_session_configure_link
usb_ssh_session_wait_for_target "$IFACE" "$TARGET_ADDR" "$WAIT_SEC"

echo "INFO: reading device model from $PRODUCT_INI"
DEVICE_MODEL="$(
	remote "awk -F= '
		\$1 ~ /^[[:space:]]*model[[:space:]]*$/ {
			v=\$2; gsub(/^[[:space:]]+|[[:space:]]+\$/, \"\", v); print v; exit
		}
	' '$PRODUCT_INI' 2>/dev/null || true" | tr -d '\r'
)"
DEVICE_MODEL="$(printf '%s' "$DEVICE_MODEL" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[[ -n "$DEVICE_MODEL" ]] || die "device model empty/missing in $PRODUCT_INI (set OEM product.ini model=)"

echo "INFO: device model: $DEVICE_MODEL"

STAGING=""
cleanup() {
	if [[ -n "$STAGING" && -d "$STAGING" ]]; then
		rm -rf "$STAGING"
	fi
}
trap cleanup EXIT

if [[ -n "${PACKAGE_DIR:-}" ]]; then
	[[ -d "$PACKAGE_DIR" ]] || die "PACKAGE_DIR not a directory: $PACKAGE_DIR"
	[[ -f "$PACKAGE_DIR/manifest.json" ]] || die "PACKAGE_DIR missing manifest.json: $PACKAGE_DIR"
	LOCAL_PKG="$PACKAGE_DIR"
	echo "INFO: using PACKAGE_DIR override: $LOCAL_PKG"
else
	[[ -d "$ASSET_DIR" ]] || die "missing process-library source: $ASSET_DIR"

	export ASSET_DIR DEVICE_MODEL
	MATCH="$(
		python3 - <<'PY'
import os, re, sys
from pathlib import Path

asset_dir = Path(os.environ["ASSET_DIR"])
model = os.environ["DEVICE_MODEL"].strip()
want_dir = model.replace(" ", "_")
version_re = re.compile(r"^\d+(?:\.\d+){0,2}$")

def norm_ver(stem: str) -> str:
    if len(stem) >= 2 and stem[0] in "vV" and stem[1].isdigit():
        return stem[1:]
    return stem

def cmp_ver(a: str, b: str) -> int:
    def parts(v: str):
        return [int(p) for p in v.split("+", 1)[0].split("-", 1)[0].split(".")]
    pa, pb = parts(a), parts(b)
    for i in range(3):
        ai = pa[i] if i < len(pa) else 0
        bi = pb[i] if i < len(pb) else 0
        if ai != bi:
            return (ai > bi) - (ai < bi)
    return 0

dirs = [p for p in asset_dir.iterdir() if p.is_dir() and not p.name.startswith(".")]
available = sorted(p.name for p in dirs)

# Prefer exact underscore dir (case-insensitive), else product-model match.
chosen = None
for p in dirs:
    if p.name.lower() == want_dir.lower():
        chosen = p
        break
if chosen is None:
    for p in dirs:
        product = p.name.replace("_", " ")
        if product.lower() == model.lower():
            chosen = p
            break

if chosen is None:
    avail = ", ".join(available) if available else "(none)"
    print(f"NO_MATCH\t{model}\t{avail}", file=sys.stderr)
    sys.exit(2)

candidates = []
for xlsx in chosen.glob("*.xlsx"):
    ver = norm_ver(xlsx.stem)
    if not version_re.fullmatch(ver):
        continue
    candidates.append((ver, xlsx))
if not candidates:
    print(f"NO_XLSX\t{chosen.name}", file=sys.stderr)
    sys.exit(3)

best_ver, best_xlsx = candidates[0]
for ver, path in candidates[1:]:
    if cmp_ver(ver, best_ver) > 0:
        best_ver, best_xlsx = ver, path

print(f"{chosen.name}\t{best_ver}\t{best_xlsx}")
PY
	)" || {
		rc=$?
		case "$rc" in
		2) die "no process-library matches device model \"$DEVICE_MODEL\" under $ASSET_DIR" ;;
		3) die "matched model dir has no valid <version>.xlsx" ;;
		*) die "failed to select process-library for model \"$DEVICE_MODEL\"" ;;
		esac
	}

	MODEL_DIR_NAME="$(printf '%s' "$MATCH" | cut -f1)"
	LIB_VERSION="$(printf '%s' "$MATCH" | cut -f2)"
	XLSX_PATH="$(printf '%s' "$MATCH" | cut -f3-)"
	[[ -f "$XLSX_PATH" ]] || die "selected xlsx missing: $XLSX_PATH"

	STAGING="$(mktemp -d "${TMPDIR:-/tmp}/pl-upgrade.XXXXXX")"
	echo "INFO: converting $XLSX_PATH (model=$DEVICE_MODEL version=$LIB_VERSION)"
	python3 "$ROOT/scripts/convert-process-library.py" \
		"$XLSX_PATH" \
		--version "$LIB_VERSION" \
		--models "$DEVICE_MODEL" \
		--model-dir "$MODEL_DIR_NAME" \
		--output-dir "$STAGING" \
		--asset-key-prefix "assets/.generated/process-library" \
		|| die "convert-process-library.py failed"
	[[ -f "$STAGING/manifest.json" ]] || die "convert did not write manifest.json"
	LOCAL_PKG="$STAGING"
fi

STAMP="$(date +%Y%m%d%H%M%S)"
REMOTE_PKG="${UPGRADE_ROOT}/${STAMP}"

echo "INFO: uploading package → $REMOTE_PKG"
remote "mkdir -p '$UPGRADE_ROOT' && rm -rf '$REMOTE_PKG' && mkdir -p '$REMOTE_PKG'"
tar -C "$LOCAL_PKG" -cf - . | remote "tar -C '$REMOTE_PKG' -xf -" \
	|| die "failed to upload process-library package"

echo "INFO: writing upgrade command: $CMD_PATH"
remote "mkdir -p /run/hmi && printf 'upgrade %s\\n' '$REMOTE_PKG' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"

echo "OK: process-library upgrade command sent (force import, no version gate)"
echo "INFO: filter device logs with: make logs GREP=UpgradeProcessLibrary"
