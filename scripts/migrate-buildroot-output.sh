#!/usr/bin/env bash
# Move legacy Buildroot output dirs (*_lws_hmi_p1 / *_prebuilt) → rockchip_rk3566_rk3568_lws_hmi
# so unified make build-rootfs continues incrementally (no full rebuild).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" == Darwin && "${LWS_HMI_DOCKER:-}" != "1" ]]; then
  exec bash "$ROOT/scripts/docker-run.sh" \
    bash -c 'export LWS_HMI_DOCKER=1; exec bash /work/lws-hmi/scripts/migrate-buildroot-output.sh'
fi

SDK="${LWS_HMI_SDK_DIR:-$ROOT/linux-sdk}"
OUT_BASE="${SDK}/buildroot/output"
TARGET_NAME="${BR_OUTPUT:-rockchip_rk3566_rk3568_lws_hmi}"
TARGET="${OUT_BASE}/${TARGET_NAME}"
STAMP="$(date +%Y%m%d-%H%M%S)"
FORCE="${FORCE:-0}"

LEGACY_NAMES=(
  rockchip_rk3566_rk3568_lws_hmi_p1
  rockchip_rk3566_rk3568_lws_hmi_prebuilt
)

die() {
  echo "ERROR: $*" >&2
  exit 1
}

toolchain_kind() {
  local cfg="$1/.config"
  [[ -f "$cfg" ]] || { echo "unknown"; return 0; }
  if grep -q '^BR2_TOOLCHAIN_EXTERNAL=y' "$cfg"; then
    echo "external"
  elif grep -q '^BR2_TOOLCHAIN_BUILDROOT=y' "$cfg"; then
    echo "internal"
  else
    echo "unknown"
  fi
}

dir_size() {
  du -sk "$1" 2>/dev/null | awk '{print $1}'
}

dir_mtime() {
  if stat -c '%Y' "$1" >/dev/null 2>&1; then
    stat -c '%Y' "$1"
  else
    stat -f '%m' "$1"
  fi
}

newest_legacy() {
  local best="" best_mtime=0 d m
  for d in "${LEGACY_NAMES[@]}"; do
    [[ -d "${OUT_BASE}/${d}" ]] || continue
    m="$(dir_mtime "${OUT_BASE}/${d}")"
    if [[ "$m" -gt "$best_mtime" ]]; then
      best_mtime="$m"
      best="$d"
    fi
  done
  echo "$best"
}

refresh_defconfig() {
  echo "migrate-buildroot-output: refreshing .config from rockchip_rk3566_rk3568_lws_hmi_defconfig ..."
  make -C "${SDK}/buildroot" "O=output/${TARGET_NAME}" rockchip_rk3566_rk3568_lws_hmi_defconfig
}

fix_latest_symlink() {
  local link="${OUT_BASE}/latest"
  ln -sfn "$TARGET_NAME" "$link"
  echo "migrate-buildroot-output: latest → ${TARGET_NAME}"
}

fix_host_rpaths() {
  if [[ -d "${TARGET}/host" ]]; then
    BR_OUTPUT="$TARGET_NAME" bash "$ROOT/scripts/fix-buildroot-host-rpaths.sh"
  fi
}

backup_dir() {
  local src="$1" reason="$2"
  local dest="${src}.bak-${STAMP}-${reason}"
  echo "migrate-buildroot-output: backup ${src} → $(basename "$dest") (${reason})"
  mv "$src" "$dest"
}

[[ -d "$OUT_BASE" ]] || die "missing ${OUT_BASE} — run make lunch first"

SOURCE_NAME="$(newest_legacy)"
if [[ -z "$SOURCE_NAME" && ! -d "$TARGET" ]]; then
  echo "migrate-buildroot-output: no legacy output and no ${TARGET_NAME} — nothing to do"
  exit 0
fi

if [[ -n "$SOURCE_NAME" && "$SOURCE_NAME" == "$TARGET_NAME" ]]; then
  echo "migrate-buildroot-output: already using ${TARGET_NAME}"
  fix_latest_symlink
  exit 0
fi

if [[ -n "$SOURCE_NAME" ]]; then
  SOURCE="${OUT_BASE}/${SOURCE_NAME}"
  echo "migrate-buildroot-output: legacy source ${SOURCE_NAME} ($(dir_size "$SOURCE") KB)"
fi

if [[ -d "$TARGET" ]]; then
  kind="$(toolchain_kind "$TARGET")"
  echo "migrate-buildroot-output: existing ${TARGET_NAME} (toolchain=${kind}, $(dir_size "$TARGET") KB)"
  if [[ -n "${SOURCE:-}" ]]; then
    src_kind="$(toolchain_kind "$SOURCE")"
    if [[ "$kind" == "internal" && "$src_kind" == "external" ]]; then
      backup_dir "$TARGET" "internal-toolchain"
    elif [[ "$FORCE" == "1" ]]; then
      backup_dir "$TARGET" "force"
    elif [[ "$kind" == "$src_kind" && "$(dir_size "$SOURCE")" -gt "$(dir_size "$TARGET")" ]]; then
      backup_dir "$TARGET" "smaller-than-legacy"
    else
      echo "migrate-buildroot-output: keeping ${TARGET_NAME}; merging build/ stamps from legacy is unsafe."
      echo "  Re-run with FORCE=1 to replace, or delete ${TARGET} manually."
      exit 1
    fi
  fi
fi

if [[ -n "${SOURCE:-}" && ! -d "$TARGET" ]]; then
  echo "migrate-buildroot-output: mv ${SOURCE_NAME} → ${TARGET_NAME}"
  mv "$SOURCE" "$TARGET"
  for leg in "${LEGACY_NAMES[@]}"; do
    [[ "$leg" == "$SOURCE_NAME" ]] && continue
    [[ -d "${OUT_BASE}/${leg}" ]] || continue
    backup_dir "${OUT_BASE}/${leg}" "unused-legacy"
  done
  fix_latest_symlink
  fix_host_rpaths
  refresh_defconfig
  echo "migrate-buildroot-output: done — run: make lunch && make build-rootfs"
  exit 0
fi

if [[ -n "${SOURCE:-}" && -d "$TARGET" ]]; then
  echo "migrate-buildroot-output: mv ${SOURCE_NAME} → ${TARGET_NAME} (after backup)"
  mv "$SOURCE" "$TARGET"
fi

for leg in "${LEGACY_NAMES[@]}"; do
  [[ -d "${OUT_BASE}/${leg}" ]] || continue
  backup_dir "${OUT_BASE}/${leg}" "leftover-legacy"
done

fix_latest_symlink
fix_host_rpaths
refresh_defconfig
echo "migrate-buildroot-output: done — run: make lunch && make build-rootfs"
