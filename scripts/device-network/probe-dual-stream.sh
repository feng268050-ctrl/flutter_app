#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/device-network/probe-dual-stream.sh [device_serial] [camera_host]
# Example:
#   scripts/device-network/probe-dual-stream.sh 7c66b08c6b95baca 192.168.1.100

DEVICE_SERIAL="${1:-}"
CAMERA_HOST="${2:-192.168.1.100}"
RTSP_PORT="${RTSP_PORT:-554}"
CAMERA_USER="${CAMERA_USER:-admin}"
CAMERA_PASS="${CAMERA_PASS:-admin}"

if [[ -z "${DEVICE_SERIAL}" ]]; then
  DEVICE_SERIAL="$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi

if [[ -z "${DEVICE_SERIAL}" ]]; then
  echo "No adb device found. Pass serial explicitly."
  exit 1
fi

echo "Using adb device: ${DEVICE_SERIAL}"
echo "Camera host: ${CAMERA_HOST}:${RTSP_PORT}"
echo

ADB_PREFIX=(adb -s "${DEVICE_SERIAL}" shell)

echo "== Network facts =="
"${ADB_PREFIX[@]}" "ip addr | sed -n '1,80p'"
echo
"${ADB_PREFIX[@]}" "ip route"
echo
"${ADB_PREFIX[@]}" "ping -c 3 -W 1 ${CAMERA_HOST}" || true
echo

probe_path() {
  local path="$1"
  local url="rtsp://${CAMERA_HOST}/${path}"
  local auth
  auth="$(printf '%s' "${CAMERA_USER}:${CAMERA_PASS}" | base64 | tr -d '\r\n')"
  local req
  req="DESCRIBE ${url} RTSP/1.0\r\nCSeq: 2\r\nAccept: application/sdp\r\nAuthorization: Basic ${auth}\r\nUser-Agent: probe\r\n\r\n"

  local first_line
  first_line="$("${ADB_PREFIX[@]}" "printf '${req}' | timeout 3 nc ${CAMERA_HOST} ${RTSP_PORT} | sed -n '1p'")"
  first_line="${first_line:-NO_RESPONSE}"
  echo "${path} => ${first_line}"
}

echo "== RTSP path probe (DESCRIBE) =="
for p in PR0 PR1 stream1 stream2 main sub ch0_0.h264 ch0_1.h264; do
  probe_path "${p}"
done
echo

echo "Done. If PR0/PR1 are both 200 OK, dual-stream path is available."
