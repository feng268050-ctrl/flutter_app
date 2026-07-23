#!/usr/bin/env bash
# Shared helpers for /system/etc/model.properties keys.
# Source after `die()` is defined (emulator-system-common.sh, prepare-device.sh).

_model_properties_read_key() {
  local key="$1" file="$2"
  [[ -f "${file}" ]] || return 1
  grep -m1 "^${key}=" "${file}" 2>/dev/null | cut -d= -f2- | tr -d '\r' || true
}

_model_properties_die() {
  echo "ERROR: $*" >&2
  exit 1
}

# Resolve camera_type for model.properties (1=BLUE_LIGHT, 2=RED_LIGHT).
# When CAMERA_TYPE env is set, validates 1|2 or fails.
# When unset, uses existing key from from_file if valid, else defaults to 1.
resolve_camera_type_value() {
  local from_file="${1:-}"
  if [[ -n "${CAMERA_TYPE:-}" ]]; then
    case "${CAMERA_TYPE}" in
      1|2)
        printf '%s' "${CAMERA_TYPE}"
        return 0
        ;;
      *)
        if declare -F die >/dev/null 2>&1; then
          die "CAMERA_TYPE must be 1 (BLUE_LIGHT) or 2 (RED_LIGHT); got: ${CAMERA_TYPE}"
        fi
        _model_properties_die "CAMERA_TYPE must be 1 (BLUE_LIGHT) or 2 (RED_LIGHT); got: ${CAMERA_TYPE}"
        ;;
    esac
  fi
  local existing=""
  if [[ -n "${from_file}" ]]; then
    existing="$(_model_properties_read_key camera_type "${from_file}")"
  fi
  if [[ -n "${existing}" ]]; then
    case "${existing}" in
      1|2)
        printf '%s' "${existing}"
        return 0
        ;;
      *)
        echo "WARN: invalid camera_type=${existing} in model.properties, using 1" >&2
        printf '1'
        return 0
        ;;
    esac
  fi
  printf '1'
}

# Resolve focus_scale_ref for model.properties (signed integer).
# When FOCUS_SCALE_REF env is set, validates signed integer or fails.
# When unset, uses existing key from from_file if valid, else defaults to 0.
resolve_focus_scale_ref_value() {
  local from_file="${1:-}"
  if [[ -n "${FOCUS_SCALE_REF:-}" ]]; then
    if [[ "${FOCUS_SCALE_REF}" =~ ^-?[0-9]+$ ]]; then
      printf '%s' "${FOCUS_SCALE_REF}"
      return 0
    fi
    if declare -F die >/dev/null 2>&1; then
      die "FOCUS_SCALE_REF must be a signed integer; got: ${FOCUS_SCALE_REF}"
    fi
    _model_properties_die "FOCUS_SCALE_REF must be a signed integer; got: ${FOCUS_SCALE_REF}"
  fi
  local existing=""
  if [[ -n "${from_file}" ]]; then
    existing="$(_model_properties_read_key focus_scale_ref "${from_file}")"
  fi
  if [[ -n "${existing}" ]]; then
    if [[ "${existing}" =~ ^-?[0-9]+$ ]]; then
      printf '%s' "${existing}"
      return 0
    fi
    echo "WARN: invalid focus_scale_ref=${existing} in model.properties, using 0" >&2
    printf '0'
    return 0
  fi
  printf '0'
}

# Resolve control_card_comm_alarm_mode for model.properties (slide_window|immediate).
# When CONTROL_CARD_COMM_ALARM_MODE env is set, validates slide_window|immediate or fails.
# When unset, uses existing key from from_file if valid, else defaults to slide_window.
resolve_control_card_comm_alarm_mode_value() {
  local from_file="${1:-}"
  if [[ -n "${CONTROL_CARD_COMM_ALARM_MODE:-}" ]]; then
    case "${CONTROL_CARD_COMM_ALARM_MODE}" in
      slide_window|immediate)
        printf '%s' "${CONTROL_CARD_COMM_ALARM_MODE}"
        return 0
        ;;
      *)
        if declare -F die >/dev/null 2>&1; then
          die "CONTROL_CARD_COMM_ALARM_MODE must be slide_window or immediate; got: ${CONTROL_CARD_COMM_ALARM_MODE}"
        fi
        _model_properties_die "CONTROL_CARD_COMM_ALARM_MODE must be slide_window or immediate; got: ${CONTROL_CARD_COMM_ALARM_MODE}"
        ;;
    esac
  fi
  local existing=""
  if [[ -n "${from_file}" ]]; then
    existing="$(_model_properties_read_key control_card_comm_alarm_mode "${from_file}")"
  fi
  if [[ -n "${existing}" ]]; then
    case "${existing}" in
      slide_window|immediate)
        printf '%s' "${existing}"
        return 0
        ;;
      *)
        echo "WARN: invalid control_card_comm_alarm_mode=${existing} in model.properties, using slide_window" >&2
        printf 'slide_window'
        return 0
        ;;
    esac
  fi
  printf 'slide_window'
}

# Validate model.properties key (lowercase identifier).
validate_model_property_key() {
  local key="$1"
  if [[ "${key}" =~ ^[a-z][a-z0-9_]*$ ]]; then
    return 0
  fi
  if declare -F die >/dev/null 2>&1; then
    die "invalid property key '${key}' (use lowercase letters, digits, underscores)"
  fi
  _model_properties_die "invalid property key '${key}' (use lowercase letters, digits, underscores)"
}

# Upsert key=value in a local properties file (replace existing key or append).
upsert_model_property_in_file() {
  local key="$1" value="$2" file="$3"
  local tmp line
  validate_model_property_key "${key}"
  tmp="$(mktemp)"
  if [[ -f "${file}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      [[ "${line}" =~ ^${key}= ]] && continue
      [[ -z "${line}" ]] && continue
      printf '%s\n' "${line}" >> "${tmp}"
    done < "${file}"
  fi
  printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
  mv "${tmp}" "${file}"
}

# Remove key=... line from a local properties file (no-op if key absent).
delete_model_property_from_file() {
  local key="$1" file="$2"
  local tmp line found=0
  validate_model_property_key "${key}"
  [[ -f "${file}" ]] || return 0
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^${key}= ]]; then
      found=1
      continue
    fi
    [[ -z "${line}" ]] && continue
    printf '%s\n' "${line}" >> "${tmp}"
  done < "${file}"
  if [[ "${found}" -eq 1 ]]; then
    mv "${tmp}" "${file}"
    return 0
  fi
  rm -f "${tmp}"
  return 1
}
