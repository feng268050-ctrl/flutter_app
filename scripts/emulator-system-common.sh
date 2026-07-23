#!/usr/bin/env bash
set -euo pipefail

# Repo .env (align with Makefile WITH_DOTENV: pre-set ADB_SERIAL / MODEL / EMULATOR_PORT win over .env).
_lws_ui_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
__lws_env_adb="${ADB_SERIAL-}"
__lws_env_model="${MODEL-}"
__lws_env_sn="${SN-}"
__lws_env_camera_ip="${CAMERA_IP-}"
__lws_env_camera_type="${CAMERA_TYPE-}"
__lws_env_host_ip="${HOST_IP-}"
__lws_env_emulator_port="${EMULATOR_PORT-}"
set -a
[[ -f "${_lws_ui_root}/.env" ]] && source "${_lws_ui_root}/.env"
set +a
[[ -n "${__lws_env_adb}" ]] && export ADB_SERIAL="${__lws_env_adb}"
[[ -n "${__lws_env_model}" ]] && export MODEL="${__lws_env_model}"
[[ -n "${__lws_env_sn}" ]] && export SN="${__lws_env_sn}"
[[ -n "${__lws_env_camera_ip}" ]] && export CAMERA_IP="${__lws_env_camera_ip}"
[[ -n "${__lws_env_camera_type}" ]] && export CAMERA_TYPE="${__lws_env_camera_type}"
[[ -n "${__lws_env_host_ip}" ]] && export HOST_IP="${__lws_env_host_ip}"
[[ -n "${__lws_env_emulator_port}" ]] && export EMULATOR_PORT="${__lws_env_emulator_port}"
unset __lws_env_adb __lws_env_model __lws_env_sn __lws_env_camera_ip __lws_env_camera_type __lws_env_host_ip __lws_env_emulator_port _lws_ui_root

# adb target: ADB_SERIAL selects device; default serial matches make emulator (emulator-${EMULATOR_PORT}).
EMULATOR_PORT="${EMULATOR_PORT:-5554}"
SERIAL="${ADB_SERIAL:-emulator-${EMULATOR_PORT}}"
# AVD name is not configured via env — same rule as make emulator: slug(MODEL) or Custom_Tablet. Drop any stray AVD= from .env.
unset AVD
if [[ -n "${MODEL:-}" ]]; then
  AVD="$(printf '%s' "${MODEL}" | tr ' ' '_')"
else
  AVD="Custom_Tablet"
fi
PERM_XML="${PERM_XML:-permissions/privapp-permissions-com.lasercyber.lws.ui.xml}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# shellcheck source=model-properties-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model-properties-common.sh"

adb_bin() {
  command adb -s "${SERIAL}" "$@"
}

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "${script_dir}/.." && pwd
}

ensure_tools() {
  command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
}

device_state() {
  adb devices 2>/dev/null | awk -v serial="${SERIAL}" '$1 == serial {print $2; exit}'
}

wait_for_device() {
  adb_bin wait-for-device
}

# Resolve PID for a package: `pidof` matches kernel comm (max 15 chars), so long applicationIds
# never match. Prefer pgrep -f against the full cmdline.
adb_pkg_pid() {
  local pkg="$1"
  local p
  p="$(adb_bin shell pgrep -f -- "${pkg}" 2>/dev/null | head -n1 | tr -d '\r \t\n')"
  if [[ -n "${p}" ]] && [[ "${p}" =~ ^[0-9]+$ ]]; then
    echo "${p}"
    return 0
  fi
  p="$(adb_bin shell pidof "${pkg}" 2>/dev/null | awk '{print $1}' | tr -d '\r \t\n')"
  if [[ -n "${p}" ]]; then
    echo "${p}"
    return 0
  fi
  return 1
}

clear_user_update() {
  local pkg="com.lasercyber.lws.ui"
  echo "== clear any stale system-app update: ${pkg}" >&2
  adb_bin shell pm uninstall-system-updates "${pkg}" >/dev/null 2>&1 || true
  adb_bin shell cmd package uninstall-system-updates "${pkg}" >/dev/null 2>&1 || true
}

wait_for_boot() {
  local i boot max_iter="${LWS_EMULATOR_BOOT_MAX_WAIT_ITER:-90}"
  wait_for_device
  echo "== wait for Android boot_completed=1" >&2
  for i in $(seq 1 "${max_iter}"); do
    boot="$(adb_bin shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "${boot}" == "1" ]]; then
      echo "OK: boot completed" >&2
      return 0
    fi
    sleep 2
  done
  die "${SERIAL} did not report sys.boot_completed=1 within ~$((max_iter * 2))s"
}

# make run: require an already-attached adb device; do not launch emulator.
ensure_device_for_run() {
  local state
  state="$(device_state || true)"
  if [[ "${state}" != "device" ]]; then
    die "no adb device at ${SERIAL} (state: ${state:-missing}). Connect a device that adb lists as state \"device\" and that supports adb root and adb remount (e.g. the writable-system AVD from \"make emulator\"; typical locked retail phones will not work)."
  fi
  wait_for_boot
}

build_apk() {
  echo "== build APK: make build" >&2
  bash -c "make build"
  [[ -f app/build/outputs/apk/staging/app-staging.apk ]] \
    || die "APK not found after build: app/build/outputs/apk/staging/app-staging.apk"
}

root_and_remount() {
  wait_for_device
  echo "== adb root" >&2
  adb_bin root || true
  sleep 1
  wait_for_device

  echo "== adb remount" >&2
  local remount_output
  remount_output="$(adb_bin remount 2>&1 || true)"
  printf '%s\n' "${remount_output}" >&2

  if echo "${remount_output}" | grep -q "Now reboot your device for settings to take effect"; then
    echo "== reboot once for overlayfs/remount settings" >&2
    adb_bin reboot
    wait_for_boot
    echo "== adb root after remount reboot" >&2
    adb_bin root || true
    sleep 1
    wait_for_device
    echo "== adb remount after remount reboot" >&2
    adb_bin remount
  elif ! echo "${remount_output}" | grep -q "remount succeeded"; then
    die "adb remount did not succeed"
  fi
}

# Primary LAN IPv4 of the dev host (default-route interface). Empty when unknown.
# Manual check: bash -c 'source scripts/emulator-system-common.sh; resolve_host_lan_ipv4'
resolve_host_lan_ipv4() {
  local iface ip
  case "$(uname -s)" in
    Darwin)
      iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}')"
      [[ -n "${iface}" ]] || return 1
      ip="$(ipconfig getifaddr "${iface}" 2>/dev/null || true)"
      ;;
    Linux)
      ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
      [[ -n "${ip}" ]] || ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
      ;;
    *)
      return 1
      ;;
  esac
  ip="${ip//$'\r'/}"
  if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf '%s' "${ip}"
    return 0
  fi
  return 1
}

# Used by make emulator; merges env + detected host_ip into on-device model.properties every run.
sync_model_properties() {
  local target="/system/etc/model.properties"
  local pulled merged model_value sn_value camera_ip_value camera_type_value focus_scale_ref_value control_card_comm_alarm_mode_value host_ip_value detected_host
  pulled="$(mktemp)"
  merged="$(mktemp)"
  trap 'rm -f "${pulled}" "${merged}"' RETURN

  if adb_bin pull "${target}" "${pulled}" >/dev/null 2>&1 && [[ -s "${pulled}" ]]; then
    cp "${pulled}" "${merged}"
  else
    : > "${merged}"
  fi

  model_value="${MODEL:-$(_model_properties_read_key model "${merged}")}"
  sn_value="${SN:-$(_model_properties_read_key sn "${merged}")}"
  camera_ip_value="${CAMERA_IP:-$(_model_properties_read_key camera_ip "${merged}")}"

  if [[ -n "${HOST_IP:-}" ]]; then
    host_ip_value="${HOST_IP}"
  elif detected_host="$(resolve_host_lan_ipv4 || true)" && [[ -n "${detected_host}" ]]; then
    host_ip_value="${detected_host}"
  else
    host_ip_value="$(_model_properties_read_key host_ip "${merged}")"
  fi

  camera_type_value="$(resolve_camera_type_value "${merged}")"
  focus_scale_ref_value="$(resolve_focus_scale_ref_value "${merged}")"
  control_card_comm_alarm_mode_value="$(resolve_control_card_comm_alarm_mode_value "${merged}")"

  echo "== sync ${target} (model/sn/camera_ip/camera_type/focus_scale_ref/control_card_comm_alarm_mode/host_ip)" >&2
  : > "${merged}"
  [[ -n "${model_value}" ]] && printf 'model=%s\n' "${model_value}" >> "${merged}"
  [[ -n "${sn_value}" ]] && printf 'sn=%s\n' "${sn_value}" >> "${merged}"
  [[ -n "${camera_ip_value}" ]] && printf 'camera_ip=%s\n' "${camera_ip_value}" >> "${merged}"
  printf 'camera_type=%s\n' "${camera_type_value}" >> "${merged}"
  printf 'focus_scale_ref=%s\n' "${focus_scale_ref_value}" >> "${merged}"
  printf 'control_card_comm_alarm_mode=%s\n' "${control_card_comm_alarm_mode_value}" >> "${merged}"
  [[ -n "${host_ip_value}" ]] && printf 'host_ip=%s\n' "${host_ip_value}" >> "${merged}"

  adb_bin push "${merged}" "${target}" >/dev/null \
    || die "failed to push model config to ${target}"
  adb_bin shell chmod 0644 "${target}" >/dev/null 2>&1 || true
  adb_bin shell chown root:root "${target}" >/dev/null 2>&1 || true
  adb_bin shell restorecon "${target}" >/dev/null 2>&1 || true
  [[ -n "${host_ip_value}" ]] && echo "OK: host_ip=${host_ip_value}" >&2
  echo "OK: camera_type=${camera_type_value}" >&2
  echo "OK: focus_scale_ref=${focus_scale_ref_value}" >&2
  echo "OK: control_card_comm_alarm_mode=${control_card_comm_alarm_mode_value}" >&2
}

# Deprecated alias; prefer sync_model_properties.
push_model_properties() {
  sync_model_properties
}

ensure_adb_server_listen_all_interfaces() {
  local adb_bin_path="${1:-}"
  [[ -n "${adb_bin_path}" ]] || die "ensure_adb_server_listen_all_interfaces: adb path required"
  echo "== adb kill-server; adb -a server start (listen 0.0.0.0)" >&2
  "${adb_bin_path}" kill-server 2>/dev/null || true
  "${adb_bin_path}" -a server start
}

push_privapp() {
  clear_user_update
  local apk="app/build/outputs/apk/staging/app-staging.apk"
  [[ -f "${apk}" ]] || die "APK not found: ${apk}"
  echo "== push APK to /system/priv-app/LwsUI/LwsUI.apk" >&2
  adb_bin shell mkdir -p "/system/priv-app/LwsUI"
  adb_bin push "${apk}" "/system/priv-app/LwsUI/LwsUI.apk"
  adb_bin shell chmod 0644 "/system/priv-app/LwsUI/LwsUI.apk"
  adb_bin shell chown root:root "/system/priv-app/LwsUI/LwsUI.apk" 2>/dev/null || true
}

push_permissions() {
  [[ -f "${PERM_XML}" ]] || die "permission XML not found: ${PERM_XML}"
  echo "== push privapp permissions XML" >&2
  adb_bin push "${PERM_XML}" "/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml"
  adb_bin shell chmod 0644 "/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml"
  adb_bin shell chown root:root "/system/etc/permissions/privapp-permissions-com.lasercyber.lws.ui.xml" 2>/dev/null || true
}

reboot_and_verify() {
  echo "== reboot" >&2
  adb_bin reboot
  wait_for_boot

  echo "== verify package path" >&2
  local path
  local dump
  path="$(adb_bin shell pm path com.lasercyber.lws.ui 2>/dev/null | tr -d '\r' || true)"
  echo "${path}"
  [[ -n "${path}" ]] || die "package not found after reboot"

  if echo "${path}" | grep -q "package:/system/priv-app/LwsUI/LwsUI.apk"; then
    dump="$(adb_bin shell dumpsys package com.lasercyber.lws.ui 2>/dev/null | tr -d '\r' || true)"
    if ! echo "${dump}" | grep -q "android.permission.NETWORK_SETTINGS: granted=true"; then
      echo "WARN: NETWORK_SETTINGS not granted=true after system-app install; relying on privileged-app bypass" >&2
    fi
    return 0
  fi

  dump="$(adb_bin shell dumpsys package com.lasercyber.lws.ui 2>/dev/null | tr -d '\r' || true)"
  if echo "${dump}" | grep -q "PRIVATE_FLAG_PRIVILEGED\|privileged=true\|isPrivilegedApp=true"; then
    if ! echo "${dump}" | grep -q "android.permission.NETWORK_SETTINGS: granted=true"; then
      echo "WARN: NETWORK_SETTINGS not granted=true even though package is privileged; relying on privileged-app bypass" >&2
    fi
    echo "WARN: pm path does not point at /system/priv-app, but dumpsys still marks the app privileged." >&2
    return 0
  fi

  if echo "${path}" | grep -q "package:/data/app/"; then
    echo "== package is still an updated system app; removing update and rechecking" >&2
    clear_user_update
    path="$(adb_bin shell pm path com.lasercyber.lws.ui 2>/dev/null | tr -d '\r' || true)"
    echo "${path}"
    if echo "${path}" | grep -q "package:/system/priv-app/LwsUI/LwsUI.apk"; then
      return 0
    fi
  fi

  die "unexpected package path: ${path:-<empty>}"
}

# Best-effort launch; returns 0 when the app is running, 1 when skipped or launch failed.
try_start_app() {
  local pkg="com.lasercyber.lws.ui"
  local activity="${pkg}/.activitys.SplashActivity"
  local path out pid="" i
  path="$(adb_bin shell pm path "${pkg}" 2>/dev/null | head -1 | cut -d: -f2 | tr -d '\r' || true)"
  if [[ -z "${path}" ]]; then
    echo "INFO: ${pkg} not installed on ${SERIAL}; skip launch" >&2
    echo "INFO: run ENABLE_LENS_DET_APP=true make ai AI_INSTALL=1 or make install" >&2
    return 1
  fi
  echo "== start app on ${SERIAL}: ${pkg}" >&2
  adb_bin shell am force-stop "${pkg}" >/dev/null 2>&1 || true
  # Do not use `am start -W` here: SplashActivity may never report idle and blocks boot scripts.
  out="$(adb_bin shell am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "${activity}" 2>&1 | tr -d '\r' || true)"
  if [[ -n "${out}" ]]; then
    echo "${out}" >&2
  fi
  if echo "${out}" | grep -qiE '(^Error|error type|Activity class .* does not exist|Unable to resolve)'; then
    echo "WARN: am start failed for ${pkg}" >&2
    return 1
  fi
  for i in $(seq 1 40); do
    pid="$(adb_pkg_pid "${pkg}" || true)"
    [[ -n "${pid}" ]] && break
    sleep 0.5
  done
  if [[ -n "${pid}" ]]; then
    echo "OK: ${pkg} pid=${pid} on ${SERIAL}" >&2
    return 0
  fi
  echo "WARN: ${pkg} did not show a process after launch on ${SERIAL}" >&2
  return 1
}

start_app() {
  try_start_app || die "app did not start: com.lasercyber.lws.ui"
}

# Map host http://127.0.0.1:5580/ → guest DeviceLocalHttpServer (adb forward).
setup_emulator_local_http_forward() {
  local sdk_root="${1:-}"
  local emu_port="${EMULATOR_PORT:-5554}"
  local emu_serial="emulator-${emu_port}"
  local adb attempt out listed

  [[ -n "${sdk_root}" ]] || die "setup_emulator_local_http_forward: sdk root required"
  if [[ -n "${ADB_SERIAL:-}" && "${ADB_SERIAL}" == emulator-* ]]; then
    emu_serial="${ADB_SERIAL}"
    emu_port="${emu_serial#emulator-}"
  fi
  adb="${sdk_root}/platform-tools/adb"
  [[ -x "${adb}" ]] || adb="$(command -v adb)"
  command -v "${adb}" >/dev/null 2>&1 || die "adb not found (install Android SDK platform-tools)"

  ensure_adb_server_listen_all_interfaces "${adb}"

  if ! "${adb}" devices 2>/dev/null | awk -v s="${emu_serial}" '$1 == s && $2 == "device" { found = 1 } END { exit !found }'; then
    echo "WARN: ${emu_serial} not listed as adb device; skip tcp:5580 forward" >&2
    return 1
  fi

  # Host tcp:5580 is global per adb server — clear stale mapping before rebinding to the emulator.
  "${adb}" forward --remove "tcp:5580" >/dev/null 2>&1 || true

  for attempt in 1 2 3; do
    out="$("${adb}" -s "${emu_serial}" forward "tcp:5580" "tcp:5580" 2>&1)" || true
    listed="$("${adb}" -s "${emu_serial}" forward --list 2>/dev/null || true)"
    if printf '%s\n' "${listed}" | grep -Fq "${emu_serial} tcp:5580 tcp:5580"; then
      echo "INFO: local HTTP http://127.0.0.1:5580/ → ${emu_serial}:5580 (adb forward)" >&2
      return 0
    fi
    echo "WARN: adb forward tcp:5580 attempt ${attempt}/3 failed: ${out:-no mapping in forward --list}" >&2
    sleep 1
  done

  echo "ERROR: could not forward host :5580 to ${emu_serial}. Try:" >&2
  echo "  ${adb} forward --remove tcp:5580" >&2
  echo "  ${adb} -s ${emu_serial} forward tcp:5580 tcp:5580" >&2
  echo "  curl http://127.0.0.1:5580/lasercyber" >&2
  return 1
}

# After make install reboot: re-forward when the install adb target is an emulator (forward rules do not survive reboot).
maybe_setup_emulator_local_http_forward() {
  local sdk_root="${1:-}"
  local serial="${ADB_SERIAL:-}"
  local adb

  [[ -n "${sdk_root}" ]] || return 0
  adb="${sdk_root}/platform-tools/adb"
  [[ -x "${adb}" ]] || adb="$(command -v adb)"
  if [[ -z "${serial}" ]]; then
    serial="$("${adb}" devices 2>/dev/null | awk '$2 == "device" { print $1; exit }')" || true
  fi
  [[ -n "${serial}" && "${serial}" == emulator-* ]] || return 0
  export EMULATOR_PORT="${serial#emulator-}"
  setup_emulator_local_http_forward "${sdk_root}" || true
}
