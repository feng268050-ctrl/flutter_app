#!/usr/bin/env bash
# Extract Rockchip Linux SDK xz split volumes → repo-root linux-sdk/ (gitignored).
#
# Usage:
#   make extract-linux-sdk SRC=/path/to/volume-dir
#   make extract-linux-sdk /path/to/volume-dir
#
# Expects either:
#   name.tar.xzaa + name.tar.xzab + …  (Innohi / Rockchip split volumes)
#   or a single name.tar.xz
#
# Optional:
#   FORCE=1   replace an existing linux-sdk/
#   DEST=…    override extract target (default: <repo>/linux-sdk)
#   TRIM=1    run make trim-linux-sdk (whitelist + platform squash) after extract
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SRC:-${1:-}}"
DEST="${DEST:-$ROOT/linux-sdk}"
FORCE="${FORCE:-0}"
TRIM="${TRIM:-0}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF' >&2
Usage:
  make extract-linux-sdk SRC=/path/to/sdk-volumes
  make extract-linux-sdk /path/to/sdk-volumes

Options:
  FORCE=1   replace existing linux-sdk/
  DEST=dir  extract target (default: <repo>/linux-sdk)
  TRIM=1    trim to owned whitelist + squash platform overlay after extract
EOF
}

[[ -n "$SRC" ]] || {
  usage
  die "missing SDK volume directory (pass SRC=… or a positional path)"
}
[[ -d "$SRC" ]] || die "not a directory: $SRC"
command -v xz >/dev/null || die "xz not found (install xz / xz-utils)"
command -v tar >/dev/null || die "tar not found"

SRC="$(cd "$SRC" && pwd)"

# Prefer split volumes (*.tar.xzaa …); fall back to a single *.tar.xz.
parts=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  parts+=("$line")
done < <(find "$SRC" -maxdepth 1 -type f -name '*.tar.xz??' | LC_ALL=C sort)

mode="split"
if [[ ${#parts[@]} -eq 0 ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    parts+=("$line")
  done < <(find "$SRC" -maxdepth 1 -type f -name '*.tar.xz' ! -name '*.tar.xz??' | LC_ALL=C sort)
  mode="single"
fi

[[ ${#parts[@]} -gt 0 ]] || die "no *.tar.xz?? split volumes or *.tar.xz in $SRC"

if [[ "$mode" == "split" ]]; then
  first="$(basename "${parts[0]}")"
  [[ "$first" == *.tar.xzaa ]] || die "expected first split part to end in .tar.xzaa, got: $first"
  prefix="${first%.tar.xzaa}"
  for p in "${parts[@]}"; do
    base="$(basename "$p")"
    [[ "$base" == "${prefix}.tar.xz"* ]] || die "split part prefix mismatch: $base (expected ${prefix}.tar.xz…)"
  done
fi

if [[ -e "$DEST" ]]; then
  if [[ "$FORCE" != "1" ]]; then
    die "destination exists: $DEST (re-run with FORCE=1 to replace)"
  fi
fi

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/lws-extract-sdk.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "extract-linux-sdk: source=$SRC ($mode, ${#parts[@]} file(s))"
du -sh "${parts[@]}" 2>/dev/null | sed 's/^/  /' || true
echo "extract-linux-sdk: unpacking → $tmpdir (this can take several minutes)…"

if [[ "$mode" == "split" ]]; then
  # shellcheck disable=SC2094
  cat "${parts[@]}" | xz -dc | tar -x -C "$tmpdir"
else
  if [[ ${#parts[@]} -ne 1 ]]; then
    die "multiple *.tar.xz found; keep one archive or use split volumes"
  fi
  tar -xJf "${parts[0]}" -C "$tmpdir"
fi

# Archive root is usually a single directory (e.g. rk356x_linux6.1_…).
shopt -s nullglob dotglob
entries=("$tmpdir"/*)
shopt -u nullglob dotglob
[[ ${#entries[@]} -gt 0 ]] || die "archive extracted empty under $tmpdir"

sdk_root=""
if [[ ${#entries[@]} -eq 1 && -d "${entries[0]}" ]]; then
  sdk_root="${entries[0]}"
else
  sdk_root="$tmpdir"
fi

[[ -f "$sdk_root/build.sh" || -f "$sdk_root/Makefile" ]] || \
  echo "WARNING: extracted tree has no build.sh/Makefile at top — check SDK layout" >&2

# Stage beside DEST, then swap (avoid leaving a half-written linux-sdk/).
parent="$(dirname "$DEST")"
base="$(basename "$DEST")"
stage="$parent/.${base}.extracting.$$"
rm -rf "$stage"
mkdir -p "$parent"

# Move extracted tree out of tmpdir before EXIT cleanup.
if [[ "$sdk_root" == "$tmpdir" ]]; then
  trap - EXIT
  mv "$sdk_root" "$stage"
else
  mv "$sdk_root" "$stage"
fi

if [[ -e "$DEST" ]]; then
  echo "extract-linux-sdk: removing existing $DEST"
  rm -rf "$DEST"
fi
mv "$stage" "$DEST"

echo "extract-linux-sdk: done → $DEST"
ls -la "$DEST" | head -20

if [[ "$TRIM" == "1" ]]; then
  echo "extract-linux-sdk: TRIM=1 → trim-linux-sdk"
  DEST="$DEST" LWS_HMI_SDK_DIR="$DEST" bash "$ROOT/scripts/trim-linux-sdk.sh"
fi

if [[ "$(cd "$DEST" && pwd)" == "$(cd "$ROOT/linux-sdk" 2>/dev/null && pwd)" ]]; then
  echo "Next (macOS): make docker-volume-init   # or make docker-volume-sync if volume already exists"
  if [[ "$TRIM" == "1" ]]; then
    echo "Next:           make apply-overlay   # product/OEM + third-party packages (platform already squashed)"
  else
    echo "Next:           make trim-linux-sdk && make apply-overlay   # or TRIM=1 on extract"
  fi
fi
