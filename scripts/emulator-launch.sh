#!/usr/bin/env bash
# Start Android emulator for LWS UI local work (used by `make emulator`).
# - -avd name: if MODEL is set, spaces in MODEL become underscores for the AVD id; if MODEL is unset, use Custom_Tablet.
# - /system/etc/model.properties: synced every run (model/sn/camera_ip/host_ip); host_ip auto-detected from dev host LAN when unset.
# - If EMULATOR_RECREATE=1: removes the same-named AVD (if any) then recreates it (fresh userdata). Default: reuse existing AVD; create only if missing.
# - If REBUILD_IMAGE=1: same as EMULATOR_RECREATE=1 (preferred flag shared with make rknn).
# - If the AVD id is missing, creates it with avdmanager from the resolved API "default" (AOSP) system image.
# - Resolves API "default" (AOSP) system image under ANDROID_SDK_ROOT only to auto-create a missing AVD; launch uses the AVD's own system image (same as `emulator -avd …` in Studio).
# - Patches AVD config.ini: 2560x1600 @ 320dpi (default, matches device; 1280x800dp layouts). Override via EMULATOR_LCD_*.
#   Alt: 1280x800 px @ 160dpi (same logical size). Do NOT use 1280x800 px @ 320dpi (640x400dp, clips UI).
# - Optional EMULATOR_SCALE (e.g. 0.75): host window zoom only; guest resolution unchanged.
# - Optional EMULATOR_NO_AUDIO=1: add emulator -no-audio.
# - After boot: immersive.full for com.lasercyber.lws.ui (+ in-app) so status/nav bars do not eat the 800dp height.
# - After prepare + lens_det AI ensure: start_app (force-stop + launch SplashActivity on emulator serial).
# - setup_emulator_local_http_forward: adb -a server start, then adb -s emulator-<port> forward tcp:5580 (ignores ADB_SERIAL in .env).
# - Launch: emulator -avd <name> -writable-system -no-snapshot-load -port <EMULATOR_PORT> (always) plus optional -gpu/-scale/-no-audio.
# - Starts the emulator, waits for boot, remounts /system rw, pushes privapp permissions XML, then sync_model_properties.
# - Emulator process runs as a child job; this script waits until it exits (terminal stays attached via wait).
# - The emulator binary may print WARNING lines about adb + settings put screen_off_timeout during startup:
#   it runs before emulator-<port> is online in adb — timing race, harmless. This script pins ANDROID_HOME/PATH
#   to one SDK adb and re-applies screen_off_timeout after boot_completed.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Shared rebuild flag across targets:
# - make rknn: REBUILD_IMAGE=1 rebuilds the Docker converter image
# - make emulator: REBUILD_IMAGE=1 deletes + recreates the AVD (fresh userdata)
if [[ "${REBUILD_IMAGE:-}" == "1" ]]; then
  export EMULATOR_RECREATE=1
fi

# API level for system/vendor images (AOSP "default" tag only).
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

# Prefer host ABI: arm64 Mac -> arm64-v8a first; Intel -> x86_64 first.
api30_aosp_system_vendor() {
  local sdk="$1" api="${EMULATOR_API_LEVEL}" abis=()
  case "$(uname -m)" in
    arm64|aarch64) abis=(arm64-v8a x86_64) ;;
    *) abis=(x86_64 arm64-v8a) ;;
  esac
  local abi dir
  for abi in "${abis[@]}"; do
    dir="${sdk}/system-images/android-${api}/default/${abi}"
    if [[ -f "${dir}/system.img" ]]; then
      echo "${dir}"
      return 0
    fi
  done
  return 1
}

# e.g. .../system-images/android-30/default/arm64-v8a -> system-images;android-30;default;arm64-v8a
sysimg_package_key() {
  local sdk="${1%/}" dir="$2"
  local rel="${dir#${sdk}/}"
  printf '%s' "${rel}" | tr '/' ';'
}

resolve_avdmanager() {
  local sdk="$1" c
  for c in \
    "${sdk}/cmdline-tools/latest/bin/avdmanager" \
    "${sdk}/cmdline-tools/bin/avdmanager"; do
    [[ -x "$c" ]] && { echo "$c"; return 0; }
  done
  if [[ -x "${sdk}/tools/bin/avdmanager" ]]; then
    echo "${sdk}/tools/bin/avdmanager"
    return 0
  fi
  return 1
}

# Remove Quick Boot snapshots when LCD/resolution config changed (default_boot no longer loads).
clear_avd_quick_boot_snapshots() {
  local avd="$1"
  local snap="${ANDROID_AVD_HOME:-$HOME/.android/avd}/${avd}.avd/snapshots"
  if [[ -d "${snap}" ]]; then
    echo "INFO: removing Quick Boot snapshots: ${snap}" >&2
    rm -rf "${snap}"
  fi
}

list_running_emulator_serials() {
  adb devices 2>/dev/null | awk 'NR > 1 && $1 ~ /^emulator-[0-9]+$/ { print $1, $2 }'
}

emulator_avd_name_for_serial() {
  local serial="$1" avd_name=""
  avd_name="$(adb -s "${serial}" shell getprop qemu.avd_name 2>/dev/null | tr -d '\r' | head -n1 || true)"
  if [[ -z "${avd_name}" ]]; then
    avd_name="$(adb -s "${serial}" shell getprop ro.boot.qemu.avd_name 2>/dev/null | tr -d '\r' | head -n1 || true)"
  fi
  printf '%s' "${avd_name}"
}

stop_running_emulators_for_avd() {
  local avd="$1" serial state avd_name stopped=0
  if ! command -v adb >/dev/null 2>&1; then
    return 0
  fi
  adb start-server >/dev/null 2>&1 || true
  while read -r serial state; do
    [[ -n "${serial}" ]] || continue
    [[ "${state}" == "device" || "${state}" == "offline" ]] || continue
    avd_name="$(emulator_avd_name_for_serial "${serial}" || true)"
    if [[ "${avd_name}" == "${avd}" ]]; then
      echo "INFO: stopping stale emulator ${serial} for AVD ${avd}" >&2
      adb -s "${serial}" emu kill >/dev/null 2>&1 || true
      stopped=1
    fi
  done < <(list_running_emulator_serials)

  if [[ "${stopped}" == "1" ]]; then
    sleep 2
  fi
}

resolve_emulator_serial() {
  local avd="$1" preferred="$2" serial state avd_name
  local attempt
  for attempt in $(seq 1 90); do
    state="$(adb devices 2>/dev/null | awk -v s="${preferred}" '$1 == s { print $2; exit }')"
    if [[ "${state}" == "device" ]]; then
      printf '%s' "${preferred}"
      return 0
    fi

    while read -r serial state; do
      [[ -n "${serial}" ]] || continue
      [[ "${serial}" =~ ^emulator-[0-9]+$ ]] || continue
      [[ "${state}" == "device" ]] || continue
      avd_name="$(emulator_avd_name_for_serial "${serial}" || true)"
      if [[ "${avd_name}" == "${avd}" ]]; then
        if [[ "${serial}" != "${preferred}" ]]; then
          echo "WARN: emulator for AVD ${avd} came up as ${serial} instead of ${preferred}; continuing with detected serial" >&2
        fi
        printf '%s' "${serial}"
        return 0
      fi
    done < <(list_running_emulator_serials)

    sleep 2
  done

  return 1
}

# Guest LCD default: 2560x1600 @ 320dpi => 1280x800dp (same as hardware).
patch_avd_config_for_lws_tablet_resolution() {
  local avd="$1"
  local lcd_width="${EMULATOR_LCD_WIDTH:-2560}"
  local lcd_height="${EMULATOR_LCD_HEIGHT:-1600}"
  local lcd_density="${EMULATOR_LCD_DENSITY:-320}"
  local root="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
  local ini="${root}/${avd}.avd/config.ini"
  [[ -f "${ini}" ]] || die "missing AVD config.ini: ${ini}"
  local result
  result="$(python3 - "${ini}" "${lcd_width}" "${lcd_height}" "${lcd_density}" <<'PY'
import sys

path = sys.argv[1]
lcd_width = sys.argv[2]
lcd_height = sys.argv[3]
lcd_density = sys.argv[4]
updates = {
    "hw.lcd.width": lcd_width,
    "hw.lcd.height": lcd_height,
    "hw.lcd.density": lcd_density,
    "hw.initialOrientation": "landscape",
}
with open(path, encoding="utf-8", errors="replace") as f:
    raw = f.read()
cur = {}
for line in raw.splitlines():
    s = line.strip()
    if not s or s.startswith("#") or "=" not in s:
        continue
    k, v = s.split("=", 1)
    cur[k.strip()] = v.strip()
if all(cur.get(k) == v for k, v in updates.items()):
    print("UNCHANGED")
    sys.exit(0)
lines = raw.splitlines(keepends=True)
out = []
seen = set()
for line in lines:
    s = line.strip()
    if not s or s.startswith("#"):
        out.append(line)
        continue
    if "=" not in s:
        out.append(line)
        continue
    k = s.split("=", 1)[0].strip()
    if k in updates:
        seen.add(k)
        out.append(f"{k}={updates[k]}\n")
    else:
        out.append(line)
for k, v in updates.items():
    if k not in seen:
        out.append(f"{k}={v}\n")
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write("".join(out))
print("CHANGED")
sys.exit(0)
PY
)" || die "patch AVD config failed"
  result="$(printf '%s' "${result}" | tr -d '\r\n' | tr -d ' ')"
  if [[ "${result}" == "CHANGED" ]]; then
    clear_avd_quick_boot_snapshots "${avd}"
  fi
}

# Stop emulator on this port if running, then remove AVD from avdmanager + disk.
remove_avd_for_fresh_create() {
  local avd="$1" sdk="$2"
  local avdman avd_root ini dir port serial
  port="${EMULATOR_PORT:-5554}"
  serial="emulator-${port}"
  stop_running_emulators_for_avd "${avd}"
  if command -v adb >/dev/null 2>&1; then
    adb start-server >/dev/null 2>&1 || true
    adb -s "${serial}" emu kill >/dev/null 2>&1 || true
  fi
  avdman="$(resolve_avdmanager "${sdk}")" || die "avdmanager not found under ${sdk}/cmdline-tools/... Install Android SDK Command-line Tools (latest)."
  avd_root="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
  ini="${avd_root}/${avd}.ini"
  dir="${avd_root}/${avd}.avd"
  echo "INFO: replacing AVD $(printf '%q' "${avd}") with a fresh instance (delete + recreate)" >&2
  "${avdman}" delete avd -n "${avd}" 2>/dev/null || true
  rm -rf "${dir}"
  rm -f "${ini}"
  if emulator -list-avds 2>/dev/null | grep -Fqx -- "${avd}"; then
    die "Could not remove AVD $(printf '%q' "${avd}"); stop any emulator using it (e.g. adb -s ${serial} emu kill) and retry."
  fi
}

# Create AVD if missing (non-interactive: decline custom hardware profile).
ensure_avd_exists() {
  local avd="$1" pkg_key="$2" sdk="$3"
  if emulator -list-avds 2>/dev/null | grep -Fqx -- "${avd}"; then
    return 0
  fi
  local avdman
  avdman="$(resolve_avdmanager "${sdk}")" || die "avdmanager not found under ${sdk}/cmdline-tools/... Install Android SDK Command-line Tools (latest)."
  echo "INFO: creating AVD $(printf '%q' "${avd}") from package ${pkg_key}" >&2
  printf 'no\n' | "${avdman}" create avd -n "${avd}" -k "${pkg_key}" \
    || die "avdmanager create avd failed (see stderr). If the name is rejected, use letters/numbers or underscores."
  emulator -list-avds 2>/dev/null | grep -Fqx -- "${avd}" \
    || die "AVD ${avd} still not listed after create; check avdmanager output."
}

command -v emulator >/dev/null 2>&1 || die "emulator not found in PATH (install Android SDK cmdline-tools / emulator)."

sdk_root="$(resolve_sdk_root)" || die "ANDROID_SDK_ROOT / ANDROID_HOME not set and no SDK found in ~/Library/Android/sdk or ~/Android/Sdk."

# One SDK root + one adb on PATH (avoids mixing Homebrew adb vs SDK; emulator still may WARN if adb races boot).
export ANDROID_SDK_ROOT="${sdk_root}"
export ANDROID_HOME="${sdk_root}"
PATH="${sdk_root}/platform-tools:${PATH}"
export PATH

sys_dir="$(api30_aosp_system_vendor "${sdk_root}")" || {
  echo "ERROR: No AOSP API ${EMULATOR_API_LEVEL} system image (tag: default)." >&2
  echo "Install one of:" >&2
  echo "  sdkmanager \"system-images;android-${EMULATOR_API_LEVEL};default;arm64-v8a\"" >&2
  echo "  sdkmanager \"system-images;android-${EMULATOR_API_LEVEL};default;x86_64\"" >&2
  echo "Expected: ${sdk_root}/system-images/android-${EMULATOR_API_LEVEL}/default/<abi>/system.img" >&2
  exit 1
}

# AVD id for -avd / avdmanager: MODEL with spaces -> underscores; if MODEL unset, Custom_Tablet.
avd_from_model() {
  if [[ -z "${MODEL:-}" ]]; then
    echo "Custom_Tablet"
    return 0
  fi
  printf '%s' "${MODEL}" | tr ' ' '_'
}

AVD="$(avd_from_model)"
export AVD
package_key="$(sysimg_package_key "${sdk_root}" "${sys_dir}")"
if [[ "${EMULATOR_RECREATE:-0}" == "1" ]]; then
  remove_avd_for_fresh_create "${AVD}" "${sdk_root}"
fi
ensure_avd_exists "${AVD}" "${package_key}" "${sdk_root}"

cd "${ROOT_DIR}"
# shellcheck source=emulator-system-common.sh
source "${ROOT_DIR}/scripts/emulator-system-common.sh"
# common loads .env; MODEL→AVD slug only matters here (make run ignores MODEL).
[[ -n "${MODEL:-}" ]] || die "MODEL is required for 'make emulator' (e.g. MODEL=\"LaserCyber L1\" make emulator)"
[[ -n "${SN:-}" ]] || die "SN is required for 'make emulator' (e.g. SN=54b515de0f9d06f2 make emulator)"
AVD="$(avd_from_model)"
export AVD
EMULATOR_PORT="${EMULATOR_PORT:-5554}"
SERIAL="emulator-${EMULATOR_PORT}"
ensure_tools

emu_cmd=(emulator -avd "${AVD}" -writable-system -no-snapshot-load)
emu_cmd+=(-port "${EMULATOR_PORT}")
[[ -n "${EMULATOR_GPU:-}" ]] && emu_cmd+=(-gpu "${EMULATOR_GPU}")
[[ -n "${EMULATOR_SCALE:-}" ]] && emu_cmd+=(-scale "${EMULATOR_SCALE}")
[[ "${EMULATOR_NO_AUDIO:-0}" == "1" ]] && emu_cmd+=(-no-audio)
patch_avd_config_for_lws_tablet_resolution "${AVD}"

echo "INFO: AVD=$(printf '%q' "${AVD}") LCD ${EMULATOR_LCD_WIDTH:-2560}x${EMULATOR_LCD_HEIGHT:-1600} @ ${EMULATOR_LCD_DENSITY:-320}dpi (1280x800dp layouts)" >&2
echo "INFO: system image for new AVDs: ${sys_dir}/system.img" >&2
printf 'INFO: emulator command:' >&2
printf ' %q' "${emu_cmd[@]}" >&2
printf '\n' >&2

command -v adb >/dev/null 2>&1 && adb start-server >/dev/null 2>&1 || true

"${emu_cmd[@]}" &
emu_pid=$!

SERIAL="$(resolve_emulator_serial "${AVD}" "${SERIAL}")" || die "emulator for AVD ${AVD} did not come up on ${SERIAL}"
export ADB_SERIAL="${SERIAL}"
export ANDROID_SERIAL="${SERIAL}"
echo "INFO: using adb serial ${SERIAL}" >&2

wait_for_boot
# Match emulator's intent (max timeout ms); early boot adb attempt often loses the race and logs WARNING.
adb_bin shell settings put system screen_off_timeout 2147483647 >/dev/null 2>&1 || true
# Full immersive for LWS (status + nav hidden like YNH on device).
adb_bin shell settings put global policy_control "immersive.full=com.lasercyber.lws.ui:*" >/dev/null 2>&1 \
  || adb_bin shell settings put global policy_control "immersive.full=*" >/dev/null 2>&1 || true
adb_bin shell wm density "${EMULATOR_LCD_DENSITY:-320}" >/dev/null 2>&1 || true
echo "INFO: guest display: $(adb_bin shell wm size 2>/dev/null | tr -d '\r' | head -1), density: $(adb_bin shell wm density 2>/dev/null | tr -d '\r' | head -1)" >&2
root_and_remount
push_permissions
sync_model_properties
export ADB_SERIAL="${SERIAL}"
export ANDROID_SERIAL="${SERIAL}"
"${ROOT_DIR}/scripts/emulator-ensure-ai-opencv-stain-detect.sh" || die "emulator OpenCV stain detect AI install failed (set EMULATOR_AI_INSTALL=0 to skip)"
start_app

setup_emulator_local_http_forward "${sdk_root}" || true

echo "INFO: waiting on emulator (pid=${emu_pid}); close the emulator window to finish." >&2
wait "${emu_pid}"
