#!/usr/bin/env bash
# Keep output/.config aligned with board/ynh960_defconfig (lunch does not re-merge on every build).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK="${SDK_DIR:-$ROOT/linux-sdk}"
CFG="$SDK/output/.config"
DEF="${LWS_BOARD_DEF:-$ROOT/board/ynh960_defconfig}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -r "$CFG" ]] || die "missing $CFG — run: make lunch"
[[ -r "$DEF" ]] || die "missing $DEF"

apply_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$CFG" 2>/dev/null; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|" "$CFG"
  else
    echo "${key}=${val}" >>"$CFG"
  fi
}

# Kconfig booleans use "# KEY is not set" when off — plain append does not enable them.
apply_bool() {
  local key="$1" val="$2"
  sed -i.bak \
    -e "/^# ${key} is not set$/d" \
    -e "/^${key}=./d" \
    "$CFG"
  if [[ "$val" == "y" ]]; then
    echo "${key}=y" >>"$CFG"
  else
    echo "# ${key} is not set" >>"$CFG"
  fi
}

apply_from_def() {
  local key="$1" val="$2"
  case "$val" in
    y|n) apply_bool "$key" "$val" ;;
    *) apply_kv "$key" "\"$val\"" ;;
  esac
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue
  key="${line%%=*}"
  val="${line#*=}"
  val="$(echo "$val" | sed 's/^"\(.*\)"$/\1/')"
  apply_from_def "$key" "$val"
done <"$DEF"

# Default SDK demo FIT (includes resource.img) unless board defconfig overrides.
if ! grep -q '^RK_BOOT_FIT_ITS_NAME=' "$DEF" 2>/dev/null; then
  apply_kv "RK_BOOT_FIT_ITS_NAME" '"boot.its"'
fi
apply_kv "RK_BOOT_FIT_ITS" '"$RK_CHIP_DIR/$RK_BOOT_FIT_ITS_NAME"'

# ynh960 A/B: factory package must map each boot partition to its matching,
# hash-valid FIT (boot.img=rootfs_a, boot_b.img=rootfs_b).
apply_bool "RK_PACKAGE_FILE_CUSTOM" "y"
apply_kv "RK_PACKAGE_FILE" '"package-file-ynh960-linux-ab"'

echo "sync-lunch-config: applied $(basename "$DEF") → output/.config"
