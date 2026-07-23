#!/usr/bin/env bash
# Re-apply host :5580 → emulator DeviceLocalHttpServer (see setup_emulator_local_http_forward).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=emulator-system-common.sh
source "${ROOT_DIR}/scripts/emulator-system-common.sh"

resolve_sdk_root() {
  local d
  for d in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME}/Library/Android/sdk" "${HOME}/Android/Sdk"; do
    [[ -n "$d" && -d "$d" ]] || continue
    if [[ -d "$d/platform-tools" || -d "$d/emulator" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

sdk_root="$(resolve_sdk_root)" || die "ANDROID_SDK_ROOT / ANDROID_HOME not set and no SDK found"
export ANDROID_SDK_ROOT="${sdk_root}"
export ANDROID_HOME="${sdk_root}"
PATH="${sdk_root}/platform-tools:${PATH}"
export PATH

EMULATOR_PORT="${EMULATOR_PORT:-5554}"
setup_emulator_local_http_forward "${sdk_root}"
