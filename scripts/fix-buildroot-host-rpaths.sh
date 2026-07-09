#!/usr/bin/env bash
# After migrate-buildroot-output renames output/, the tree may still reference the old
# directory (e.g. *_lws_hmi_p1): ELF RUNPATH, autoconf/automake Perl paths, .la/.pc, etc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    bash -c 'export LWS_HMI_DOCKER=1; exec bash /work/lws-hmi/scripts/fix-buildroot-host-rpaths.sh'
fi

SDK="${LWS_HMI_SDK_DIR:-$(bash "$ROOT/scripts/link-sdk.sh" --print 2>/dev/null || true)}"
OUT_BASE="${SDK}/buildroot/output"
TARGET_NAME="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
OUT_DIR="${OUT_BASE}/${TARGET_NAME}"

LEGACY_SUFFIXES=(
  rockchip_rk3566_rk3568_lws_hmi_p1
  rockchip_rk3566_rk3568_lws_hmi_prebuilt
)

FIX_DIRS=(host build staging target)

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v patchelf >/dev/null 2>&1 || die "patchelf not found"

[[ -d "$OUT_DIR" ]] || die "missing ${OUT_DIR} — run make lunch first"

fix_elf_rpath() {
  local file="$1"
  local rpath new suffix

  rpath="$(patchelf --print-rpath "$file" 2>/dev/null || true)"
  [[ -n "$rpath" ]] || return 0

  new="$rpath"
  for suffix in "${LEGACY_SUFFIXES[@]}"; do
    [[ "$suffix" == "$TARGET_NAME" ]] && continue
    new="${new//${OUT_BASE}\/${suffix}/${OUT_BASE}/${TARGET_NAME}}"
  done

  [[ "$new" != "$rpath" ]] || return 0
  patchelf --set-rpath "$new" "$file"
  echo "fix-rpath: ${file#${OUT_DIR}/}"
}

fix_text_paths_in_dir() {
  local dir="$1"
  local suffix old new file

  [[ -d "$dir" ]] || return 0

  for suffix in "${LEGACY_SUFFIXES[@]}"; do
    [[ "$suffix" == "$TARGET_NAME" ]] && continue
    old="${OUT_BASE}/${suffix}"
    new="${OUT_BASE}/${TARGET_NAME}"
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      sed -i "s|${old}|${new}|g" "$file"
      echo "fix-path: ${file#${OUT_DIR}/}"
    done < <(grep -rlIF "$old" "$dir" 2>/dev/null || true)
  done
}

rpath_fixed=0
while IFS= read -r file; do
  fix_elf_rpath "$file" && rpath_fixed=$((rpath_fixed + 1)) || true
done < <(find "$OUT_DIR" -type f \( -perm -111 -o -name '*.so*' \) 2>/dev/null)

echo "fix-buildroot-host-rpaths: ELF RUNPATH updated in ${rpath_fixed} file(s)"

for sub in "${FIX_DIRS[@]}"; do
  fix_text_paths_in_dir "$OUT_DIR/$sub"
done

remaining="$(grep -r "lws_hmi_p1\|lws_hmi_prebuilt" "$OUT_DIR/host" "$OUT_DIR/build" 2>/dev/null | wc -l | tr -d ' ')"
echo "fix-buildroot-host-rpaths: done (${remaining} legacy path reference(s) left under host/ + build/)"

if [[ "$remaining" != "0" ]]; then
  echo "  (binary blobs may still contain strings — safe to ignore if build continues)" >&2
fi
