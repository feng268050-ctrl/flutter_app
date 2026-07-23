#!/usr/bin/env bash
# Preflight + prepare: physical adb device, /system writable (auto-enable via verity flow if needed),
# and rewrite priv-app permissions XML for com.lasercyber.lws.ui.
# Honors ADB_SERIAL. Exit 1 on any failure; messages to stderr.
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=adb-device-common.sh
source "${SCRIPT_DIR}/adb-device-common.sh"
# shellcheck source=../model-properties-common.sh
source "${SCRIPT_DIR}/../model-properties-common.sh"

need_adb() {
  command -v adb >/dev/null 2>&1 || die "adb not found in PATH"
}

device_ready() {
  local out
  # Only physical devices are supported for HMI tests; filter out emulator-xxxx.
  out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1}')"
  [[ -n "$out" ]] || return 1
  if [[ -z "${ADB_SERIAL:-}" ]]; then
    local n
    n="$(echo "$out" | wc -l | tr -d ' ')"
    [[ "$n" -eq 1 ]] || die "Multiple physical devices; set ADB_SERIAL or use adb -s. Found: $(echo "$out" | tr '\n' ' ')"
  else
    [[ "${ADB_SERIAL}" =~ ^emulator- ]] && die "Emulator is not supported for HMI tests: ${ADB_SERIAL}"
    echo "$out" | grep -qx "${ADB_SERIAL}" || return 1
  fi
  return 0
}

ensure_device_ready() {
  if device_ready; then
    return 0
  fi
  if is_network_adb_serial; then
    echo "INFO: ${ADB_SERIAL} not in 'device' state; running adb connect..." >&2
    try_adb_connect
    sleep 1
    device_ready && return 0
  fi
  return 1
}

root_exec() {
  if adb_bin shell sh -c "$1" 2>/dev/null; then
    return 0
  fi
  # Avoid hanging on some builds where su requires interaction.
  adb_bin shell 'command -v su >/dev/null 2>&1' 2>/dev/null || return 1
  adb_bin shell su 0 sh -c "$1" </dev/null 2>/dev/null
}

ensure_root_context() {
  adb_root_and_wait
  if adb_bin shell id 2>/dev/null | tr -d '\r' | grep -q 'uid=0'; then
    return 0
  fi
  if adb_bin shell 'command -v su >/dev/null 2>&1' 2>/dev/null; then
    adb_bin shell su 0 id </dev/null 2>/dev/null | tr -d '\r' | grep -q 'uid=0' \
      || die "root context unavailable (adb root/su 0 not usable)"
    return 0
  fi
  die "root context unavailable (adb root/su 0 not usable)"
}

adb_root_and_wait() {
  adb_bin root >/dev/null 2>&1 || true
  sleep 1
  adb_bin wait-for-device >/dev/null 2>&1 || true
}

system_mount_line() {
  adb_bin shell 'mount | grep " /system "' 2>/dev/null | tr -d '\r' | head -n 1 || true
}

system_is_rw_by_mount() {
  local line
  line="$(system_mount_line)"
  [[ -n "$line" ]] || return 1
  # Avoid fragile regex handling; use shell pattern match for mount variants:
  #   "... (rw,seclabel,...)"
  #   "... rw,seclabel,..."
  [[ "$line" == *"(rw"* || "$line" == *" rw,"* ]]
}

ensure_system_rw() {
  adb_root_and_wait
  local cur_mount
  cur_mount="$(system_mount_line)"
  echo "INFO: current /system mount: ${cur_mount:-<not found>}" >&2
  if system_is_rw_by_mount; then
    echo "INFO: /system is already rw; skip prepare flow." >&2
    return 0
  fi

  echo "INFO: /system is read-only; running standard rw preparation flow..." >&2
  echo "INFO: adb root -> disable-verity -> reboot -> adb root -> adb remount" >&2

  adb_bin disable-verity || die "disable-verity failed (requires root-capable build)"
  adb_bin reboot >/dev/null 2>&1 || die "reboot failed"
  wait_boot_after_reboot
  adb_root_and_wait
  echo "INFO: running adb remount..." >&2
  adb_bin remount || die "adb remount failed after disable-verity/reboot"

  # remount can take a moment to reflect in mount output.
  local i
  for i in $(seq 1 10); do
    if system_is_rw_by_mount; then
      echo "INFO: /system mount: $(system_mount_line)" >&2
      echo "INFO: /system remounted rw successfully." >&2
      return 0
    fi
    sleep 1
  done

  die "/system is not rw after root/disable-verity/reboot/remount flow (mount line: $(system_mount_line))"
}

write_privapp_xml() {
  local perms_dir="/system/etc/permissions"
  local path=""
  local source_xml="${SCRIPT_DIR}/../../permissions/privapp-permissions-com.lasercyber.lws.ui.xml"
  local tmp_remote="/data/local/tmp/privapp-permissions-com.lasercyber.lws.ui.xml"

  echo "INFO: writing priv-app permissions XML..." >&2
  [[ -f "${source_xml}" ]] || die "missing source XML: ${source_xml}"
  ensure_root_context
  echo "INFO: shell identity: $(adb_bin shell id 2>/dev/null | tr -d '\r')" >&2
  adb_bin push "${source_xml}" "${tmp_remote}" >/dev/null \
    || die "failed to push temp priv-app XML to device"

  if ! adb_bin shell "ls -ld '${perms_dir}'" >/dev/null 2>&1; then
    root_exec "ls -ld '${perms_dir}'" >/dev/null 2>&1 \
      || die "${perms_dir} does not exist or is inaccessible even with root"
  fi
  echo "INFO: using permissions dir: ${perms_dir}" >&2
  path="${perms_dir}/privapp-permissions-com.lasercyber.lws.ui.xml"

  if root_exec "cp '${tmp_remote}' '${path}'"; then
    :
  elif adb_bin push "${source_xml}" "${path}" >/dev/null 2>&1; then
    echo "INFO: cp failed, direct adb push to target path succeeded." >&2
  elif root_exec "cat '${tmp_remote}' > '${path}'"; then
    echo "INFO: cp/push failed, shell redirection write succeeded." >&2
  else
    die "failed to write ${path} via cp, adb push, or shell redirection"
  fi
  root_exec "chmod 0644 '${path}'" || true
  root_exec "chown root:root '${path}'" || true
  root_exec "restorecon '${path}'" >/dev/null 2>&1 || true
  adb_bin shell rm -f "${tmp_remote}" >/dev/null 2>&1 || true
  echo "INFO: priv-app permissions XML written: ${path}" >&2
}

write_model_config() {
  local model_value="${MODEL:-}"
  local sn_value="${SN:-}"
  local camera_ip_value="${CAMERA_IP:-}"
  local camera_type_value=""
  local focus_scale_ref_value=""
  local control_card_comm_alarm_mode_value=""
  local tmp_local=""
  local target="/system/etc/model.properties"
  if [[ -z "${model_value}" && -z "${sn_value}" && -z "${camera_ip_value}" && -z "${CAMERA_TYPE:-}" && -z "${FOCUS_SCALE_REF:-}" && -z "${CONTROL_CARD_COMM_ALARM_MODE:-}" ]]; then
    return 0
  fi
  camera_type_value="$(resolve_camera_type_value "")"
  focus_scale_ref_value="$(resolve_focus_scale_ref_value "")"
  control_card_comm_alarm_mode_value="$(resolve_control_card_comm_alarm_mode_value "")"
  echo "INFO: writing device model config to ${target}" >&2
  ensure_root_context
  tmp_local="$(mktemp)"
  [[ -n "${model_value}" ]] && printf "model=%s\n" "${model_value}" >> "${tmp_local}"
  [[ -n "${sn_value}" ]] && printf "sn=%s\n" "${sn_value}" >> "${tmp_local}"
  [[ -n "${camera_ip_value}" ]] && printf "camera_ip=%s\n" "${camera_ip_value}" >> "${tmp_local}"
  printf "camera_type=%s\n" "${camera_type_value}" >> "${tmp_local}"
  printf "focus_scale_ref=%s\n" "${focus_scale_ref_value}" >> "${tmp_local}"
  printf "control_card_comm_alarm_mode=%s\n" "${control_card_comm_alarm_mode_value}" >> "${tmp_local}"
  echo "INFO: pushing model config directly to ${target}" >&2
  adb_bin push "${tmp_local}" "${target}" >/dev/null \
    || die "failed to push model config to ${target}"
  rm -f "${tmp_local}"
  adb_bin shell chmod 0644 "${target}" >/dev/null 2>&1 || true
  adb_bin shell chown root:root "${target}" >/dev/null 2>&1 || true
  adb_bin shell restorecon "${target}" >/dev/null 2>&1 || true
  echo "INFO: device model config written: ${target}" >&2
}

need_adb
ensure_device_ready || die "No physical adb device in 'device' state (connect one device or set ADB_SERIAL)"
ensure_system_rw
write_model_config
write_privapp_xml
echo "OK: device preflight + prepare passed." >&2
