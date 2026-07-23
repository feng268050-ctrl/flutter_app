#!/usr/bin/env bash
# POST /v1/camera/show-overlay on DeviceLocalHttpServer (clock + name overlay + saveConf).
set -euo pipefail

die() {
  echo "ERROR: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=device-local-http-common.sh
source "${SCRIPT_DIR}/device-local-http-common.sh"

ENABLE=""
X=""
Y=""

usage() {
  cat <<'EOF'
Usage:
  make show-camera-overlay ENABLE=0|1 [X=<int>] [Y=<int>]

Examples:
  make show-camera-overlay ENABLE=1
  make show-camera-overlay ENABLE=1 X=20 Y=30
  make show-camera-overlay ENABLE=0

Calls POST /v1/camera/show-overlay on the device LAN HTTP server (port 5580).
The app applies clock overlay (PUT /System/showtime), name overlay using Settings
→ Device Information → Machine Model (GET/PUT /Media/Video/overlays?channel=1),
then PUT /System/saveConf.

When ENABLE=1:
  - showtime at (X, Y) with UTC clock
  - NameOverlay enable=1, x=X, y=Y+50, name=<Machine Model>
When ENABLE=0:
  - disables clock and hides device name overlay

Y max is 288; when ENABLE=1, Y must be <= 238 so Y+50 fits on screen.

Device HTTP base URL:
  DEVICE_HTTP_URL          explicit override
  ADB_SERIAL=host:5555     http://host:5580
  ADB_SERIAL=emulator-5554 http://127.0.0.1:5580 (with adb forward)
EOF
}

parse_args() {
  local o key val
  for o in "$@"; do
    case "${o}" in
      -h|--help|help)
        usage
        exit 0
        ;;
    esac
    [[ "${o}" == *=* ]] || continue
    key="${o%%=*}"
    val="${o#*=}"
    case "${key}" in
      ENABLE) ENABLE="${val}" ;;
      X) X="${val}" ;;
      Y) Y="${val}" ;;
    esac
  done
}

validate_enable() {
  case "${ENABLE}" in
    0|1) ;;
    *)
      usage
      die "ENABLE is required and must be 0 or 1 (example: make show-camera-overlay ENABLE=1)"
      ;;
  esac
}

validate_coord() {
  local name="$1" value="$2" min="$3" max="$4"
  [[ "${value}" =~ ^[0-9]+$ ]] || die "${name} must be an integer (got: ${value})"
  if (( value < min || value > max )); then
    die "${name} must be between ${min} and ${max} (got: ${value})"
  fi
}

api_success() {
  local json="$1"
  [[ "${json}" == *'"success":true'* && "${json}" == *'"code":200'* ]]
}

main() {
  parse_args "$@"

  if [[ -z "${ENABLE}" ]]; then
    usage
    die "ENABLE is required (example: make show-camera-overlay ENABLE=1)"
  fi

  X="${X:-10}"
  Y="${Y:-10}"

  validate_enable
  validate_coord X "${X}" 0 384
  if [[ "${ENABLE}" == "1" ]]; then
    validate_coord Y "${Y}" 0 238
  else
    validate_coord Y "${Y}" 0 288
  fi

  local base body response
  base="$(probe_device_local_http)"
  body="$(printf '{"enable":%s,"positionx":%s,"positiony":%s}' "${ENABLE}" "${X}" "${Y}")"
  echo "INFO: POST ${base}/v1/camera/show-overlay body=${body}" >&2
  response="$(curl -sS --connect-timeout 5 -m 45 -X POST "${base}/v1/camera/show-overlay" \
    -H 'Content-Type: application/json' \
    -d "${body}")"
  printf '%s\n' "${response}"
  if api_success "${response}"; then
    echo "OK: camera overlay applied and saved" >&2
    exit 0
  fi
  die "camera show-overlay failed"
}

main "$@"
