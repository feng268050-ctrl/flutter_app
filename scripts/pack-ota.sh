#!/usr/bin/env bash
# Build whole-device OTA tar.gz (+ optional .sig) under output/firmware/<APP>/.
# Usage: APP=lws_hmi [OEM_ONLY=1] [REQUIRE_OTA_SIG=1] bash scripts/pack-ota.sh
# Env:
#   OTA_SIGNING_KEY   PEM private key → emit sibling .sig when set
#   REQUIRE_OTA_SIG=1 fail if signing unset/unusable (publish/CI)
#   OEM_ONLY=1        package oem.img + manifest only
#   OEM_IMG           oem path (same rules as upgrade-remote.sh)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"
app_select_resolve
# shellcheck source=scripts/factory-sku.sh
source "$ROOT/scripts/factory-sku.sh"

FIRMWARE="${FIRMWARE_DIR:-$ROOT/output/firmware}"
OUT_DIR="${APP_FIRMWARE_DIR:-$FIRMWARE/$APP}"
ARCHIVE_NAME="${OTA_PACKAGE_NAME:-ota-package.tar.gz}"
ARCHIVE="$OUT_DIR/$ARCHIVE_NAME"
SIG="${ARCHIVE}.sig"
OEM_ONLY="${OEM_ONLY:-0}"
REQUIRE_OTA_SIG="${REQUIRE_OTA_SIG:-0}"
STAGE=""

die() {
	echo "ERROR: $*" >&2
	exit 1
}

cleanup() {
	[[ -n "$STAGE" && -d "$STAGE" ]] && rm -rf "$STAGE"
}
trap cleanup EXIT

usage() {
	cat <<EOF
Usage: APP=<id> [OEM_ONLY=1] [REQUIRE_OTA_SIG=1] $0

Packs partition images + manifest.json into:
  output/firmware/<APP>/ota-package.tar.gz

When OTA_SIGNING_KEY is set, also writes ota-package.tar.gz.sig.
REQUIRE_OTA_SIG=1 (publish/CI) fails if signing is unavailable.
Local make upgrade may omit .sig when the key is unset.

Env:
  APP / FIRMWARE_DIR / FACTORY_SKU / OEM_ID / OEM_IMG / OEM_ONLY
  OTA_SIGNING_KEY  OTA_PACKAGE_NAME  REQUIRE_OTA_SIG
EOF
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage && exit 0

case "$OEM_ONLY" in
0 | 1) ;;
*) die "OEM_ONLY must be 0 or 1 (got: $OEM_ONLY)" ;;
esac

# Deprecated alias → OEM_IMG
if [[ -n "${UPGRADE_OEM_IMG+x}" && -z "${OEM_IMG+x}" ]]; then
	OEM_IMG="${UPGRADE_OEM_IMG}"
	echo "WARNING: UPGRADE_OEM_IMG is deprecated; use OEM_IMG= instead" >&2
fi

if [[ -z "${OEM_IMG+x}" ]]; then
	if [[ -r "$FACTORY_OEM_IMG" ]]; then
		OEM_IMG="$FACTORY_OEM_IMG"
	else
		OEM_IMG=""
	fi
fi

BOOT_IMG="$FIRMWARE/boot.img"
BOOT_B_IMG="$FIRMWARE/boot_b.img"
ROOTFS_IMG=""

resolve_rootfs() {
	local candidate
	for candidate in "$APP_ROOTFS_IMG" "$FIRMWARE/rootfs.img" \
		"$APP_FIRMWARE_DIR/rootfs.ext2" "$FIRMWARE/rootfs.ext2"; do
		if [[ -f "$candidate" ]]; then
			ROOTFS_IMG="$candidate"
			return 0
		fi
	done
	return 1
}

file_sha256() {
	if command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" | awk '{print $1}'
	else
		sha256sum "$1" | awk '{print $1}'
	fi
}

file_size() {
	local path="$1"
	if stat -f%z "$path" >/dev/null 2>&1; then
		stat -f%z "$path"
	else
		stat -c%s "$path"
	fi
}

mkdir -p "$OUT_DIR"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/lws-pack-ota.XXXXXX")"

MEMBERS=()

if [[ "$OEM_ONLY" == "1" ]]; then
	[[ -n "$OEM_IMG" ]] || die "OEM_ONLY=1 requires oem.img — run: make build-oem (or set OEM_IMG=)"
	[[ -f "$OEM_IMG" ]] || die "OEM_IMG not found: $OEM_IMG"
	cp -f "$OEM_IMG" "$STAGE/oem.img"
	MEMBERS+=(oem.img)
else
	[[ -f "$BOOT_IMG" ]] || die "missing $BOOT_IMG — run: make build-kernel"
	[[ -f "$BOOT_B_IMG" ]] || die "missing $BOOT_B_IMG — run: make build-kernel"
	resolve_rootfs || die "missing $APP_ROOTFS_IMG — run: APP=$APP make build-rootfs"
	cp -f "$BOOT_IMG" "$STAGE/boot.img"
	cp -f "$BOOT_B_IMG" "$STAGE/boot_b.img"
	cp -f "$ROOTFS_IMG" "$STAGE/rootfs.img"
	MEMBERS+=(boot.img boot_b.img rootfs.img)
	if [[ -n "$OEM_IMG" ]]; then
		[[ -f "$OEM_IMG" ]] || die "OEM_IMG not found: $OEM_IMG"
		cp -f "$OEM_IMG" "$STAGE/oem.img"
		MEMBERS+=(oem.img)
	else
		echo "WARNING: oem.img not found at $FACTORY_OEM_IMG — packaging boot/rootfs only" >&2
	fi
fi

# Orchestration manifest (not a trust root for cloud writes).
{
	echo '{'
	echo "  \"format\": \"lws-ota-tar-v1\","
	echo "  \"app\": \"$APP\","
	echo "  \"oem_only\": $OEM_ONLY,"
	echo "  \"created_at_unix\": $(date +%s),"
	echo '  \"files\": {'
	first=1
	for name in "${MEMBERS[@]}"; do
		path="$STAGE/$name"
		sha="$(file_sha256 "$path")"
		sz="$(file_size "$path")"
		[[ $first -eq 1 ]] || echo ','
		first=0
		printf '    \"%s\": { \"sha256\": \"%s\", \"size\": %s }' "$name" "$sha" "$sz"
	done
	echo
	echo '  }'
	echo '}'
} >"$STAGE/manifest.json"
MEMBERS+=(manifest.json)

echo "pack-ota: APP=$APP OEM_ONLY=$OEM_ONLY → $ARCHIVE"
for name in "${MEMBERS[@]}"; do
	ls -lh "$STAGE/$name"
done

rm -f "$ARCHIVE" "$SIG"
# BusyBox tar on device must see flat members (rootfs.img, …). macOS bsdtar
# often emits AppleDouble ._files and GNU sparse (GNUSparseFile.0/…); prefer
# GNU tar + ustar, and always disable macOS copyfile xattrs.
export COPYFILE_DISABLE=1
TAR_BIN=tar
if command -v gtar >/dev/null 2>&1; then
	TAR_BIN=gtar
fi
# Portable: gzip tarball of members at archive root (no nested dir / no sparse).
"$TAR_BIN" -C "$STAGE" --format=ustar -czf "$ARCHIVE" "${MEMBERS[@]}" \
	|| die "tar failed ($TAR_BIN)"
# Sanity: reject host-side archives BusyBox cannot flatten.
if tar -tzf "$ARCHIVE" 2>/dev/null | grep -E '(^|/)\._|GNUSparseFile' >/dev/null; then
	die "archive contains macOS/sparse members (use gtar --format=ustar); refused: $ARCHIVE"
fi

if [[ -z "${OTA_SIGNING_KEY:-}" && -r "$ROOT/keys/ota/ed25519.pem" ]]; then
	OTA_SIGNING_KEY="$ROOT/keys/ota/ed25519.pem"
	echo "pack-ota: using default OTA_SIGNING_KEY=$OTA_SIGNING_KEY"
fi

if [[ -n "${OTA_SIGNING_KEY:-}" ]]; then
	OTA_SIGNING_KEY="$OTA_SIGNING_KEY" bash "$ROOT/scripts/ota-sign.sh" "$ARCHIVE" "$SIG" \
		|| die "signing failed"
elif [[ "$REQUIRE_OTA_SIG" == "1" ]]; then
	die "REQUIRE_OTA_SIG=1 but OTA_SIGNING_KEY unset — run: make sign-keys (or set OTA_SIGNING_KEY=)"
else
	echo "pack-ota: OTA_SIGNING_KEY unset — archive only (unsigned; SSH make upgrade / publish need .sig)"
fi

ls -lh "$ARCHIVE"
[[ -f "$SIG" ]] && ls -lh "$SIG"
echo "pack-ota: done"
echo "  archive=$ARCHIVE"
[[ -f "$SIG" ]] && echo "  signature=$SIG"
echo "  note: SSH make upgrade and make publish need archive + .sig; RockUSB di does not"
