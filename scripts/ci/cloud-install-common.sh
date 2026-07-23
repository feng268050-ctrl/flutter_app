#!/usr/bin/env bash
# Shared constants and helpers for cloud VERSION= install (make install).
set -euo pipefail

LWS_UI_PKG="${LWS_UI_PKG:-com.lasercyber.lws.ui}"
LWS_PRIV_APP_APK="${LWS_PRIV_APP_APK:-/system/priv-app/LwsUI/LwsUI.apk}"
PUBLISH_PUBLIC_BASE_URL="${PUBLISH_PUBLIC_BASE_URL:-https://pub-3955e5ba2e5e40958c5eb9bc14cca6c0.r2.dev}"
PUBLISH_API_VIEW_BASE="${PUBLISH_API_VIEW_BASE:-https://api-prod.lasercyber.workers.dev/view/lws-app}"

cloud_downgrade_state_file() {
  local root="${LWS_CLOUD_CACHE_ROOT:-build/cache/lws-app}"
  printf '%s/.cloud-was-downgrade' "$root"
}

mark_cloud_downgrade() {
  local f
  f="$(cloud_downgrade_state_file)"
  mkdir -p "$(dirname "$f")"
  : > "$f"
}

cloud_was_downgrade() {
  [[ -f "$(cloud_downgrade_state_file)" ]]
}

clear_cloud_downgrade_mark() {
  rm -f "$(cloud_downgrade_state_file)"
}

resolve_aapt() {
  local sdk dir
  if command -v aapt >/dev/null 2>&1; then
    command -v aapt
    return 0
  fi
  for sdk in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME}/Library/Android/sdk" "${HOME}/Android/Sdk"; do
    [[ -n "${sdk}" && -d "${sdk}/build-tools" ]] || continue
    dir="$(find "${sdk}/build-tools" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "${dir}" && -x "${dir}/aapt" ]]; then
      echo "${dir}/aapt"
      return 0
    fi
  done
  return 1
}

is_install_release_channel() {
  [[ "${INSTALL_RELEASE:-}" == "1" ]]
}

normalize_pack_version() {
  local raw="${1:-}"
  raw="${raw#v}"
  raw="${raw#V}"
  raw="$(printf '%s' "$raw" | tr -d '[:space:]')"
  [[ -n "$raw" ]] || return 1

  if is_install_release_channel; then
    if [[ "$raw" == *-beta ]]; then
      echo "ERROR: channel conflict: RELEASE=1 but VERSION contains -beta ($raw)" >&2
      return 1
    fi
    printf '%s' "$raw"
    return 0
  fi

  if [[ "$raw" == *-beta ]]; then
    printf '%s' "$raw"
  else
    printf '%s-beta' "$raw"
  fi
}

validate_version_triplet() {
  local name="$1"
  if [[ ! "$name" =~ ^([0-9])\.([0-9])\.([0-9]{1,2})$ ]]; then
    echo "ERROR: invalid VERSION: expected x.y.z with patch 0-99 (got $name)" >&2
    return 1
  fi
  local patch="${BASH_REMATCH[3]}"
  patch="$((10#$patch))"
  if (( patch > 99 )); then
    echo "ERROR: invalid VERSION: patch must be 0-99 (got $patch)" >&2
    return 1
  fi
}

# pm install -r -d of a priv-app path refreshes PackageManager version metadata but on
# RK / AOSP often also creates UPDATED_SYSTEM_APP under /data/app/. Strip that overlay so
# pm path returns /system/priv-app/... while keeping the refreshed versionCode.
strip_priv_app_user_update_overlay() {
  local pkg="${1:-$LWS_UI_PKG}"
  echo "INFO: stripping user-update overlay for ${pkg} (keep priv-app registration)..." >&2
  # Prefer adb_bin from adb-device-common.sh when already sourced.
  if declare -F adb_bin >/dev/null 2>&1; then
    adb_bin shell am force-stop "$pkg" >/dev/null 2>&1 || true
    adb_bin shell pm uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
    adb_bin shell cmd package uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
  elif [[ -n "${ADB_SERIAL:-}" ]]; then
    adb -s "${ADB_SERIAL}" shell am force-stop "$pkg" >/dev/null 2>&1 || true
    adb -s "${ADB_SERIAL}" shell pm uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
    adb -s "${ADB_SERIAL}" shell cmd package uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
  else
    adb shell am force-stop "$pkg" >/dev/null 2>&1 || true
    adb shell pm uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
    adb shell cmd package uninstall-system-updates "$pkg" >/dev/null 2>&1 || true
  fi
}
