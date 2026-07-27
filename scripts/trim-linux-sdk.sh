#!/usr/bin/env bash
# Trim a full Rockchip linux-sdk/ to the lws-hmi owned whitelist.
# Usage:
#   make trim-linux-sdk
#   DEST=… CLEAN_OUTPUT=1 bash scripts/trim-linux-sdk.sh
#
# Preserves buildroot/dl, buildroot/output, output unless CLEAN_OUTPUT=1.
# Installs docs/linux-sdk-vendor-import.md → linux-sdk/VENDOR_IMPORT.md
# and writes ownership marker .lws-owned-tree, then runs platform squash.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${LWS_HMI_SDK_DIR:-${DEST:-${SDK:-$ROOT/linux-sdk}}}"
WHITELIST="${WHITELIST:-$ROOT/board/linux-sdk-whitelist.txt}"
CLEAN_OUTPUT="${CLEAN_OUTPUT:-0}"
SKIP_SQUASH="${SKIP_SQUASH:-0}"
SKIP_CHECK="${SKIP_CHECK:-0}"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$WHITELIST" ]] || die "missing whitelist: $WHITELIST"
[[ -d "$SDK" ]] || die "linux-sdk missing: $SDK (extract first)"

echo "trim-linux-sdk: SDK=$SDK"

# Collect KEEP_EXTERNAL names into a newline list
KEEP_EXT_LIST=""
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    KEEP_EXTERNAL) KEEP_EXT_LIST="${KEEP_EXT_LIST}${val}"$'\n' ;;
  esac
done < "$WHITELIST"

keep_external() {
  local name="$1"
  printf '%s' "$KEEP_EXT_LIST" | grep -qxF "$name"
}

rm_rf() {
  local p="$1"
  if [[ -e "$p" || -L "$p" ]]; then
    echo "trim: rm $p"
    rm -rf "$p"
  fi
}

# Forbidden top-level
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  case "$key" in
    FORBID_TOP) rm_rf "$SDK/$val" ;;
    FORBID_PATH) rm_rf "$SDK/$val" ;;
  esac
done < "$WHITELIST"

# Drop non-whitelisted external/*
if [[ -d "$SDK/external" ]]; then
  shopt -s nullglob
  for d in "$SDK/external"/*; do
    base="$(basename "$d")"
    if ! keep_external "$base"; then
      rm_rf "$d"
    fi
  done
  shopt -u nullglob
fi

# Slim libmali: keep aarch64 + headers + build metadata; drop armhf and unused GPU .so
slim_libmali() {
  local mali="$SDK/external/libmali"
  [[ -d "$mali" ]] || return 0
  rm_rf "$mali/lib/arm-linux-gnueabihf"
  rm_rf "$mali/optimize_s"
  rm_rf "$mali/debian"
  # Keep only wayland-gbm (and matching dummy) for bifrost-g52 g24p0 (RK356x default in rockchip-mali.mk)
  if [[ -d "$mali/lib/aarch64-linux-gnu" ]]; then
    shopt -s nullglob
    for f in "$mali/lib/aarch64-linux-gnu"/libmali-*.so; do
      base="$(basename "$f")"
      case "$base" in
        libmali-bifrost-g52-g24p0-wayland-gbm.so|\
        libmali-bifrost-g52-g24p0-dummy-wayland-gbm.so|\
        libmali-bifrost-g52-g24p0-dummy.so)
          ;;
        *)
          echo "trim: rm $f"
          rm -f "$f"
          ;;
      esac
    done
    shopt -u nullglob
  fi
}
slim_libmali

# Slim rknpu2: keep runtime (+ mk/README/LICENSE); drop examples/doc/res bloat
if [[ -d "$SDK/external/rknpu2" ]]; then
  rm_rf "$SDK/external/rknpu2/examples"
  rm_rf "$SDK/external/rknpu2/doc"
  rm_rf "$SDK/external/rknpu2/res"
fi

# tools: keep linux/ (and mac if present for host helpers); drop windows
rm_rf "$SDK/tools/windows"

# u-boot/: not required. Production binaries: prebuilt/bootloader/.
# Keep optional full source (Makefile / .git from fetch-uboot); otherwise remove the dir.
# build-img / restore-sdk-loader mkdir staging under u-boot/ only when packing.
slim_uboot_staging() {
  local uboot="$SDK/u-boot"
  if [[ ! -e "$uboot" ]]; then
    echo "trim: no u-boot/ (OK — pack will mkdir if needed)"
    return 0
  fi
  if [[ -f "$uboot/Makefile" || -d "$uboot/.git" ]]; then
    echo "trim: keeping u-boot source tree"
    return 0
  fi
  echo "trim: rm $uboot (vendor blobs; prebuilt/bootloader is authoritative)"
  rm -rf "$uboot"
}
slim_uboot_staging

if [[ "$CLEAN_OUTPUT" == "1" ]]; then
  rm_rf "$SDK/buildroot/dl"
  rm_rf "$SDK/buildroot/output"
  rm_rf "$SDK/output"
else
  echo "trim: preserving buildroot/dl, buildroot/output, output (CLEAN_OUTPUT=1 to wipe)"
fi

# Install vendor import doc + local .gitignore for future track rules
mkdir -p "$SDK"
if [[ -f "$ROOT/docs/linux-sdk-vendor-import.md" ]]; then
  cp -f "$ROOT/docs/linux-sdk-vendor-import.md" "$SDK/VENDOR_IMPORT.md"
  echo "trim: installed VENDOR_IMPORT.md"
fi

cat > "$SDK/.gitignore" <<'EOF'
# Installed by trim-linux-sdk (local tree only; linux-sdk/ remains repo-gitignored).
/output/
/buildroot/dl/
/buildroot/output/
/rockdev/
# Pack staging only — created by build-img; authoritative: prebuilt/bootloader/<uboot_id>/
/u-boot/
*.orig
*.lws-hmi.orig
EOF

# Ownership marker (apply-overlay skips platform kernel/device when present)
{
  echo "# lws-hmi owned linux-sdk marker (W3). Do not commit this tree yet."
  echo "trimmed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "whitelist=board/linux-sdk-whitelist.txt"
} > "$SDK/.lws-owned-tree"
echo "trim: wrote .lws-owned-tree"

if [[ "$SKIP_SQUASH" != "1" ]]; then
  LWS_HMI_SDK_DIR="$SDK" bash "$ROOT/scripts/squash-linux-sdk-platform.sh"
fi

if [[ "$SKIP_CHECK" != "1" ]]; then
  LWS_HMI_SDK_DIR="$SDK" bash "$ROOT/scripts/check-linux-sdk-whitelist.sh"
fi

echo "trim-linux-sdk: done"
echo "NOTE (macOS): run make docker-volume-init or make docker-volume-sync so the Docker volume drops deleted paths."
