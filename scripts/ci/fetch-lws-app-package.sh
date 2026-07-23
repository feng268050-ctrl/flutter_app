#!/usr/bin/env bash
# Download a published lws-app zip from R2 and extract the APK.
# Channel: INSTALL_RELEASE=1 (make CLI RELEASE=1) → release zip; else staging -beta.
# Usage: fetch-lws-app-package.sh <VERSION>
# Prints extracted APK path on the last line of stdout.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=cloud-install-common.sh
source "${SCRIPT_DIR}/cloud-install-common.sh"

VERSION_INPUT="${1:-${VERSION:-}}"
[[ -n "$VERSION_INPUT" ]] || die "usage: $0 <VERSION>"

PACK_VERSION="$(normalize_pack_version "$VERSION_INPUT")" || exit 1
BASE_NAME="${PACK_VERSION%-beta}"
validate_version_triplet "$BASE_NAME" || exit 1

PACK_NAME="lws-app_v${PACK_VERSION}.zip"
CACHE_DIR="${ROOT}/build/cache/lws-app"
ZIP="${CACHE_DIR}/${PACK_NAME}"
ZIP_PART="${ZIP}.part"
APK_OUT="${CACHE_DIR}/extracted-${PACK_VERSION}.apk"
URL="${PUBLISH_PUBLIC_BASE_URL%/}/lws-app/${PACK_NAME}"

mkdir -p "$CACHE_DIR"

manifest_name="staging.json"
if is_install_release_channel; then
  manifest_name="release.json"
fi

verify_zip_sha512_if_latest() {
  local manifest_url="${PUBLISH_API_VIEW_BASE}/${manifest_name}"
  local raw manifest_ver expected actual
  command -v curl >/dev/null 2>&1 || return 0
  command -v python3 >/dev/null 2>&1 || return 0

  raw="$(curl -sf "$manifest_url" 2>/dev/null)" || return 0
  manifest_ver="$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('version') or '').lstrip('vV'))" <<<"$raw" 2>/dev/null || true)"
  expected="$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('sha512') or '')" <<<"$raw" 2>/dev/null || true)"

  [[ -n "$manifest_ver" && -n "$expected" ]] || return 0
  if [[ "$manifest_ver" != "$PACK_VERSION" && "$manifest_ver" != "$BASE_NAME" ]]; then
    return 0
  fi

  expected="${expected#sha512:}"
  expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  actual="$(openssl dgst -sha512 -hex "$ZIP" 2>/dev/null | awk '{print $2}' | tr '[:upper:]' '[:lower:]')"
  [[ -n "$actual" ]] || return 0
  if [[ "$actual" != "$expected" ]]; then
    die "sha512 mismatch for ${PACK_NAME} (manifest ${manifest_name})"
  fi
  echo "INFO: sha512 verified against ${manifest_name}" >&2
}

zip_is_valid() {
  [[ -f "$ZIP" ]] || return 1
  [[ -s "$ZIP" ]] || return 1
  unzip -t "$ZIP" >/dev/null 2>&1
}

download_zip() {
  echo "INFO: checking ${URL} ..." >&2
  curl -sfI "$URL" >/dev/null || die "version not found: ${PACK_NAME} (${URL})"

  echo "INFO: downloading ${PACK_NAME} ..." >&2
  rm -f "$ZIP_PART"
  curl -fL "$URL" -o "$ZIP_PART" || {
    rm -f "$ZIP_PART"
    die "download failed: ${URL}"
  }
  mv "$ZIP_PART" "$ZIP"
}

if zip_is_valid; then
  echo "INFO: reusing cached zip (integrity ok): ${ZIP}" >&2
else
  rm -f "$ZIP" "$ZIP_PART"
  download_zip
  zip_is_valid || die "downloaded zip failed integrity check: ${ZIP}"
fi

verify_zip_sha512_if_latest

select_apk_entry() {
  local list count
  list="$(unzip -Z1 "$ZIP" 2>/dev/null | grep -i '\.apk$' | grep -v '/$' || true)"
  count="$(printf '%s\n' "$list" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" -eq 0 ]]; then
    die "zip contains no .apk: ${ZIP}"
  fi
  if [[ "$count" -eq 1 ]]; then
    printf '%s\n' "$list"
    return 0
  fi
  local picked=""
  local hint
  for hint in release staging lws app-release; do
    picked="$(printf '%s\n' "$list" | grep -i "$hint" | head -n 1 || true)"
    [[ -n "$picked" ]] && break
  done
  if [[ -z "$picked" ]]; then
    picked="$(unzip -Z1 "$ZIP" | grep -i '\.apk$' | while read -r e; do
      sz="$(unzip -Z -v "$ZIP" "$e" 2>/dev/null | awk '/compressed size:/{print $3; exit}')"
      printf '%s\t%s\n' "${sz:-0}" "$e"
    done | sort -nr | head -n 1 | cut -f2-)"
  fi
  [[ -n "$picked" ]] || die "could not select apk from zip: ${ZIP}"
  printf '%s\n' "$picked"
}

APK_ENTRY="$(select_apk_entry)"
echo "INFO: extracting apk entry: ${APK_ENTRY}" >&2
rm -f "$APK_OUT"
unzip -p "$ZIP" "$APK_ENTRY" > "$APK_OUT"
chmod 0644 "$APK_OUT"

"${SCRIPT_DIR}/apk-version-read.sh" "$APK_OUT" package >/dev/null \
  || die "extracted file is not a valid APK: ${APK_OUT}"

echo "OK: cloud APK ready at ${APK_OUT}" >&2
printf '%s\n' "$APK_OUT"
