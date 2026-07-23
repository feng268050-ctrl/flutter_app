#!/usr/bin/env bash
# Persist cloud install context across wireless reboot (push / resume split).
set -euo pipefail

cloud_install_state_file() {
  local root="${LWS_CLOUD_CACHE_ROOT:-build/cache/lws-app}"
  printf '%s/.install-state.env' "$root"
}

cloud_install_save_state() {
  local apk="$1" version="$2"
  local f
  f="$(cloud_install_state_file)"
  mkdir -p "$(dirname "$f")"
  cat >"$f" <<EOF
VERSION=${version}
CLOUD_APK=${apk}
ADB_SERIAL=${ADB_SERIAL:-}
SAVED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
  echo "INFO: saved install state → ${f}" >&2
}

cloud_install_load_state() {
  local f expected_version="${1:-}"
  f="$(cloud_install_state_file)"
  [[ -f "$f" ]] || return 1
  # shellcheck disable=SC1090
  source "$f"
  [[ -n "${CLOUD_APK:-}" && -f "${CLOUD_APK}" ]] || return 1
  if [[ -n "$expected_version" && "${VERSION:-}" != "$expected_version" ]]; then
    echo "ERROR: install state VERSION=${VERSION:-} does not match requested ${expected_version}" >&2
    return 1
  fi
  return 0
}

cloud_install_clear_state() {
  rm -f "$(cloud_install_state_file)"
}
