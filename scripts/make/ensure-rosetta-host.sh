#!/usr/bin/env bash
# Re-exec under Rosetta (darwin-x86_64) on Apple Silicon so NDK r18b host tools run correctly.
# Target ABI remains Android arm64-v8a (e.g. Rockchip RK3566); only the build host arch changes.

ensure_rosetta_host_reexec() {
  local script="$1"
  shift

  if [[ "${AI_SKIP_ROSETTA:-}" == "1" ]]; then
    return 0
  fi
  if [[ "${LWS_AI_ROSETTA_ACTIVE:-}" == "1" ]]; then
    return 0
  fi
  if [[ "$(uname -s)" != "Darwin" ]] || [[ "$(uname -m)" != "arm64" ]]; then
    return 0
  fi
  if ! command -v arch >/dev/null 2>&1; then
    echo "ERROR: Apple Silicon Mac requires 'arch' to run NDK r18b (darwin-x86_64 prebuilts)." >&2
    exit 1
  fi
  if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
    cat >&2 <<'EOF'
ERROR: Rosetta 2 is not available on this Mac.

Install Rosetta (one-time):
  softwareupdate --install-rosetta --agree-to-license

Or run `make ai` from a Linux x86_64 machine / CI instead.
EOF
    exit 1
  fi

  echo "make ai: Apple Silicon (arm64) host → re-exec via Rosetta 2 (darwin-x86_64) for NDK r18b"
  echo "make ai: cross-compile target ABI=arm64-v8a (Rockchip RK3566 / RK3568 class boards)"
  export LWS_AI_ROSETTA_ACTIVE=1
  exec arch -x86_64 /bin/bash "$script" "$@"
}

validate_ndk_mac_prebuilt() {
  local ndk="${ANDROID_NDK_PATH:-}"
  if [[ "$(uname -s)" != "Darwin" ]] || [[ -z "$ndk" ]]; then
    return 0
  fi
  if [[ -d "$ndk/toolchains/llvm/prebuilt/darwin-x86_64" ]]; then
    return 0
  fi
  if [[ -d "$ndk/toolchains/aarch64-linux-android-4.9/prebuilt/darwin-x86_64" ]]; then
    return 0
  fi
  cat >&2 <<EOF
ERROR: AI NDK does not contain darwin-x86_64 prebuilts (required for r18b on Mac):
  $ndk

Expected e.g.:
  \$ndk/toolchains/llvm/prebuilt/darwin-x86_64
  \$ndk/toolchains/aarch64-linux-android-4.9/prebuilt/darwin-x86_64

Run \`make ndk-r18b\` (downloads Mac r18b into native/toolchains/ndk-r18b/ndk).
EOF
  exit 1
}

warn_if_arm64_cmake_under_rosetta() {
  if [[ "${LWS_AI_ROSETTA_ACTIVE:-}" != "1" ]]; then
    return 0
  fi
  local cmake_bin
  cmake_bin="$(command -v cmake 2>/dev/null || true)"
  [[ -n "$cmake_bin" && -x "$cmake_bin" ]] || return 0
  if file "$cmake_bin" 2>/dev/null | grep -q 'arm64'; then
    echo "make ai: WARN: cmake is arm64 ($cmake_bin); prefer x86_64 cmake under Rosetta (e.g. /usr/local/bin/cmake)" >&2
  fi
}

log_ai_build_host() {
  local host_arch target_abi rosetta_note
  host_arch="$(uname -m)"
  target_abi="arm64-v8a"
  if [[ "${LWS_AI_ROSETTA_ACTIVE:-}" == "1" ]]; then
    rosetta_note=" (Rosetta darwin-x86_64 shell)"
  else
    rosetta_note=""
  fi
  echo "make ai: host=${host_arch}${rosetta_note}, ANDROID_ABI=${target_abi}"
}
