#!/usr/bin/env bash
# Archive Buildroot host+staging for team reuse (Phase 4d).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
PROFILE="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
OUT="$SDK/buildroot/output/${PROFILE}"
DEST_DIR="$ROOT/prebuilt/buildroot-toolchain"
STAMP="$(date +%Y%m%d)"
ARCHIVE="$DEST_DIR/${PROFILE}-${STAMP}.tar.gz"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -d "$OUT/host" ]] || die "missing $OUT/host — complete a rootfs build first"
[[ -d "$OUT/staging" ]] || die "missing $OUT/staging"

mkdir -p "$DEST_DIR"
echo "export-buildroot-toolchain: packing $OUT/host + staging ..."
tar -C "$OUT" -czf "$ARCHIVE" host staging
ls -lh "$ARCHIVE"
echo "export-buildroot-toolchain: extract on new machine:"
echo "  mkdir -p $OUT && tar -C $OUT -xzf $ARCHIVE"
