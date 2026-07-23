#!/usr/bin/env bash
# One-time host setup for `make emulator`: cmdline-tools (sdkmanager/avdmanager), emulator binary, API 30 AOSP image.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

EMULATOR_API_LEVEL="${EMULATOR_API_LEVEL:-30}"

resolve_sdk_root() {
  local d
  for d in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME}/Library/Android/sdk" "${HOME}/Android/Sdk"; do
    [[ -n "$d" && -d "$d" ]] || continue
    if [[ -d "$d/system-images" || -d "$d/emulator" || -d "$d/platforms" ]]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

resolve_avdmanager() {
  local sdk="$1" c
  for c in \
    "${sdk}/cmdline-tools/latest/bin/avdmanager" \
    "${sdk}/cmdline-tools/bin/avdmanager"; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  [[ -x "${sdk}/tools/bin/avdmanager" ]] && { echo "${sdk}/tools/bin/avdmanager"; return 0; }
  return 1
}

resolve_sdkmanager() {
  local sdk="$1" c
  for c in \
    "${sdk}/cmdline-tools/latest/bin/sdkmanager" \
    "${sdk}/cmdline-tools/bin/sdkmanager"; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  [[ -x "${sdk}/tools/bin/sdkmanager" ]] && { echo "${sdk}/tools/bin/sdkmanager"; return 0; }
  return 1
}

host_abi_for_system_image() {
  case "$(uname -m)" in
    arm64|aarch64) echo "arm64-v8a" ;;
    *) echo "x86_64" ;;
  esac
}

install_cmdline_tools() {
  local sdk="$1"
  if resolve_sdkmanager "${sdk}" >/dev/null; then
    echo "INFO: cmdline-tools already present under ${sdk}/cmdline-tools"
    return 0
  fi

  local zip_name
  zip_name="$(curl -fsSL "https://dl.google.com/android/repository/repository2-3.xml" \
    | grep -oE 'commandlinetools-mac-[0-9]+_latest\.zip' | head -1)" \
    || die "could not resolve commandlinetools-mac zip from Google repository metadata"
  local url="https://dl.google.com/android/repository/${zip_name}"
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  echo "INFO: downloading ${url}" >&2
  curl -fsSL -o "${tmp}/cmdline-tools.zip" "${url}"
  unzip -q "${tmp}/cmdline-tools.zip" -d "${tmp}/extract"
  mkdir -p "${sdk}/cmdline-tools/latest"
  # Zip root is a `cmdline-tools/` directory on newer bundles; older bundles use `tools/`.
  if [[ -d "${tmp}/extract/cmdline-tools" ]]; then
    cp -R "${tmp}/extract/cmdline-tools/." "${sdk}/cmdline-tools/latest/"
  elif [[ -d "${tmp}/extract/tools" ]]; then
    cp -R "${tmp}/extract/tools/." "${sdk}/cmdline-tools/latest/"
  else
    die "unexpected cmdline-tools zip layout under ${tmp}/extract"
  fi
  resolve_sdkmanager "${sdk}" >/dev/null \
    || die "sdkmanager missing after installing cmdline-tools"
  echo "INFO: installed cmdline-tools -> ${sdk}/cmdline-tools/latest"
}

sdk_root="$(resolve_sdk_root)" || die "No Android SDK found. Set ANDROID_SDK_ROOT or install Android Studio."
export ANDROID_SDK_ROOT="${sdk_root}"
export ANDROID_HOME="${sdk_root}"
PATH="${sdk_root}/cmdline-tools/latest/bin:${sdk_root}/platform-tools:${sdk_root}/emulator:${PATH}"
export PATH

install_cmdline_tools "${sdk_root}"

sdkman="$(resolve_sdkmanager "${sdk_root}")"
abi="$(host_abi_for_system_image)"
sysimg_pkg="system-images;android-${EMULATOR_API_LEVEL};default;${abi}"

echo "INFO: accepting SDK licenses (non-interactive)" >&2
yes | "${sdkman}" --licenses >/dev/null || true

echo "INFO: installing emulator, platform-tools, platforms;android-${EMULATOR_API_LEVEL}, ${sysimg_pkg}" >&2
"${sdkman}" \
  "platform-tools" \
  "emulator" \
  "platforms;android-${EMULATOR_API_LEVEL}" \
  "${sysimg_pkg}"

command -v emulator >/dev/null 2>&1 \
  || die "emulator binary still missing after sdkmanager; check ${sdk_root}/emulator"

sys_dir="${sdk_root}/system-images/android-${EMULATOR_API_LEVEL}/default/${abi}"
[[ -f "${sys_dir}/system.img" ]] \
  || die "system image missing: ${sys_dir}/system.img"

if ! resolve_avdmanager "${sdk_root}" >/dev/null; then
  die "avdmanager missing after setup"
fi

if ! emulator -list-avds 2>/dev/null | grep -Fqx -- "Custom_Tablet"; then
  echo "INFO: creating template AVD Custom_Tablet (used when MODEL maps to a new AVD name)" >&2
  pkg_key="system-images;android-${EMULATOR_API_LEVEL};default;${abi}"
  printf 'no\n' | "$(resolve_avdmanager "${sdk_root}")" create avd -n "Custom_Tablet" -k "${pkg_key}" \
    || die "avdmanager create Custom_Tablet failed"
fi

echo ""
echo "OK: emulator host ready."
echo "  SDK: ${sdk_root}"
echo "  System image: ${sys_dir}"
echo "  AVDs: $(emulator -list-avds | tr '\n' ' ')"
echo ""
echo "Next: add to .env (see .env.example), then run:"
echo '  MODEL="LaserCyber L1" SN=<your-sn> make emulator'
