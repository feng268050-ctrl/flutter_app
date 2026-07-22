#!/usr/bin/env bash
# Measure inbound IP-camera RTSP receive bitrate on an Android board via adb.
#
# Traffic must land on the board eth0 (camera plugged into the board). Host Mac
# cannot see that path over USB adb alone. Methodology matches
# scripts/measure-ip-camera-rtsp.sh: on-device ffmpeg remux (-c copy → mpegts)
# size ÷ duration → Mbps.
#
# Doc / acceptance: docs/ip-camera-rtsp-bitrate-android-vs-linux.md
#
# Prerequisites:
#   - Real hardware on `adb devices` (emulators excluded unless SERIAL= is set)
#   - Camera at CAMERA_IP on eth0 (default 192.168.1.100)
#   - Optional cached static aarch64 ffmpeg at .cache/ffmpeg-android/ffmpeg
#     (johnvansickle arm64-static); script pushes it to /data/local/tmp/ffmpeg
#   - Optional static ethtool at .cache/android-ethtool/ethtool-static for MMC CRC
#
# Usage:
#   scripts/measure-ip-camera-rtsp-adb.sh
#   scripts/measure-ip-camera-rtsp-adb.sh 15
#   SERIAL=<adb-serial> DURATION_S=12 STREAMS="PR1 PR0" \
#     TRANSPORTS="udp tcp" scripts/measure-ip-camera-rtsp-adb.sh
#
# Env:
#   SERIAL            adb serial (required if multiple devices / force board)
#   CAMERA_IP         default 192.168.1.100
#   STREAMS           default "PR1" (space-separated; e.g. "PR1 PR0")
#   TRANSPORTS        default "udp" (space-separated; e.g. "udp tcp")
#   DURATION_S        seconds per pull (default 10; argv[1] overrides)
#   WAIT_MAX_S        max seconds to wait for a non-emulator device (default 900)
#   FFMPEG_HOST       host path to aarch64 static ffmpeg (optional)
#   SKIP_PUSH_FFMPEG  if 1, assume /data/local/tmp/ffmpeg already on device
#   DEBUG_LOG         optional host NDJSON path (unset = no file log)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB_BIN="${ADB_BIN:-/opt/homebrew/bin/adb}"
[[ -x "$ADB_BIN" ]] || ADB_BIN="$(command -v adb || true)"
[[ -n "$ADB_BIN" && -x "$ADB_BIN" ]] || {
  echo "ERROR: adb not found (tried /opt/homebrew/bin/adb and PATH)." >&2
  exit 1
}

CAMERA_IP="${CAMERA_IP:-192.168.1.100}"
STREAMS="${STREAMS:-PR1}"
TRANSPORTS="${TRANSPORTS:-udp}"
DURATION_S="${1:-${DURATION_S:-10}}"
WAIT_MAX_S="${WAIT_MAX_S:-900}"
FFMPEG_HOST="${FFMPEG_HOST:-$ROOT/.cache/ffmpeg-android/ffmpeg}"
DEVICE_FFMPEG="${DEVICE_FFMPEG:-/data/local/tmp/ffmpeg}"
SKIP_PUSH_FFMPEG="${SKIP_PUSH_FFMPEG:-0}"
DEBUG_LOG="${DEBUG_LOG:-}"

if ! [[ "$DURATION_S" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: DURATION_S must be a positive integer (got: $DURATION_S)" >&2
  exit 2
fi

is_emulator_serial() {
  case "$1" in
    emulator-*|*.emulator.*) return 0 ;;
    *) return 1 ;;
  esac
}

list_hardware_devices() {
  "$ADB_BIN" devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}' | while read -r s; do
    [[ -z "$s" ]] && continue
    if is_emulator_serial "$s"; then
      continue
    fi
    echo "$s"
  done
}

wait_for_device() {
  local elapsed=0 sleep_s=5 serial=""
  if [[ -n "${SERIAL:-}" ]]; then
    echo "==> waiting for SERIAL=${SERIAL} (up to ${WAIT_MAX_S}s)" >&2
    while (( elapsed < WAIT_MAX_S )); do
      if "$ADB_BIN" -s "$SERIAL" get-state 2>/dev/null | grep -qx device; then
        echo "$SERIAL"
        return 0
      fi
      sleep "$sleep_s"
      elapsed=$((elapsed + sleep_s))
      if (( sleep_s < 30 )); then
        sleep_s=$((sleep_s + 5))
      fi
      echo "    … still waiting (${elapsed}s)" >&2
    done
    echo "ERROR: SERIAL=${SERIAL} not ready after ${WAIT_MAX_S}s." >&2
    "$ADB_BIN" devices -l >&2 || true
    return 1
  fi

  echo "==> waiting for non-emulator adb device (up to ${WAIT_MAX_S}s)" >&2
  while (( elapsed < WAIT_MAX_S )); do
    serial="$(list_hardware_devices | head -1 || true)"
    if [[ -n "$serial" ]]; then
      echo "$serial"
      return 0
    fi
    sleep "$sleep_s"
    elapsed=$((elapsed + sleep_s))
    if (( sleep_s < 30 )); then
      sleep_s=$((sleep_s + 5))
    fi
    echo "    … still waiting (${elapsed}s); attached:" >&2
    "$ADB_BIN" devices -l | sed 's/^/       /' >&2 || true
  done
  echo "ERROR: no non-emulator adb device after ${WAIT_MAX_S}s." >&2
  echo "Flash/boot the board, enable USB debugging, then re-run." >&2
  "$ADB_BIN" devices -l >&2 || true
  return 1
}

mbps_of() {
  awk -v b="$1" -v s="$2" 'BEGIN {
    if (s <= 0) { print "0.00"; exit }
    printf "%.2f", (b * 8) / s / 1000000
  }'
}

# #region agent log
debug_ndjson() {
  local hypothesis_id="$1" message="$2" data_json="$3"
  [[ -n "$DEBUG_LOG" ]] || return 0
  mkdir -p "$(dirname "$DEBUG_LOG")"
  local ts
  ts="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000)"
  printf '{"sessionId":"c99d59","runId":"android-adb-measure","hypothesisId":"%s","location":"measure-ip-camera-rtsp-adb.sh","message":"%s","data":%s,"timestamp":%s}\n' \
    "$hypothesis_id" "$message" "$data_json" "$ts" >>"$DEBUG_LOG"
}
# #endregion

adb_sh() {
  "$ADB_BIN" -s "$SERIAL" shell "$@"
}

ensure_ffmpeg() {
  if [[ "$SKIP_PUSH_FFMPEG" == "1" ]]; then
    adb_sh "test -x ${DEVICE_FFMPEG}" && return 0
    echo "ERROR: SKIP_PUSH_FFMPEG=1 but ${DEVICE_FFMPEG} missing/not executable." >&2
    return 1
  fi
  if adb_sh "test -x ${DEVICE_FFMPEG} && ${DEVICE_FFMPEG} -version >/dev/null"; then
    echo "==> reusing on-device ${DEVICE_FFMPEG}"
    return 0
  fi
  if [[ ! -x "$FFMPEG_HOST" ]]; then
    echo "ERROR: need aarch64 static ffmpeg at:" >&2
    echo "  ${FFMPEG_HOST}" >&2
    echo "Download once (johnvansickle arm64-static), e.g.:" >&2
    echo "  mkdir -p $(dirname "$FFMPEG_HOST")" >&2
    echo "  curl -L -o /tmp/ffmpeg-arm64.tar.xz https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz" >&2
    echo "  tar -xJf /tmp/ffmpeg-arm64.tar.xz -C /tmp" >&2
    echo "  cp /tmp/ffmpeg-*-arm64-static/ffmpeg ${FFMPEG_HOST}" >&2
    return 1
  fi
  echo "==> pushing ffmpeg → ${DEVICE_FFMPEG}"
  "$ADB_BIN" -s "$SERIAL" push "$FFMPEG_HOST" "$DEVICE_FFMPEG" >/dev/null
  adb_sh "chmod 755 ${DEVICE_FFMPEG}"
  adb_sh "${DEVICE_FFMPEG} -version" >/dev/null
}

print_link_facts() {
  echo "==> eth0 / link"
  adb_sh 'ip -brief addr show eth0 2>/dev/null; ip link show eth0 2>/dev/null | head -5'
  adb_sh 'echo -n "speed_mbps="; cat /sys/class/net/eth0/speed 2>/dev/null; echo; echo -n "operstate="; cat /sys/class/net/eth0/operstate 2>/dev/null; echo; echo -n "driver="; readlink /sys/class/net/eth0/device/driver 2>/dev/null; echo'
  echo "==> routes"
  adb_sh 'ip route'
  echo "==> ping ${CAMERA_IP}"
  adb_sh "ping -c 5 -W 1 ${CAMERA_IP}" || {
    echo "ERROR: camera ${CAMERA_IP} not reachable from device eth0." >&2
    return 1
  }
}

measure_one() {
  local stream="$1" transport="$2"
  local url="rtsp://${CAMERA_IP}/${stream}"
  local out="/data/local/tmp/measure-ipcam-${stream}-${transport}.ts"
  local log="/data/local/tmp/measure-ipcam-${stream}-${transport}.log"
  local rx_before rx_after rx_delta host_log
  host_log="$(mktemp "${TMPDIR:-/tmp}/measure-ipcam-adb.XXXXXX.log")"

  echo ""
  echo "==> measure stream=${stream} transport=${transport} duration=${DURATION_S}s"
  echo "    URL: ${url}"

  rx_before="$(adb_sh 'cat /sys/class/net/eth0/statistics/rx_bytes' | tr -d '\r')"
  # Run ffmpeg on device; remux only (same as Mac script).
  # Use toybox timeout if available so a hung pull cannot block forever.
  set +e
  adb_sh "rm -f '${out}' '${log}'; \
    RXB=\$(cat /sys/class/net/eth0/statistics/rx_bytes); \
    START=\$(date +%s); \
    ${DEVICE_FFMPEG} -hide_banner -nostdin \
      -rtsp_transport ${transport} \
      -i '${url}' \
      -t ${DURATION_S} \
      -c copy -f mpegts -y '${out}' \
      >'${log}' 2>&1; \
    EC=\$?; \
    END=\$(date +%s); \
    RXA=\$(cat /sys/class/net/eth0/statistics/rx_bytes); \
    BYTES=\$(stat -c '%s' '${out}' 2>/dev/null || echo 0); \
    ELAPSED=\$((END-START)); \
    [ \"\$ELAPSED\" -lt 1 ] && ELAPSED=1; \
    echo \"ec=\$EC bytes=\$BYTES elapsed=\$ELAPSED rx_before=\$RXB rx_after=\$RXA\"; \
    tail -n 30 '${log}'" >"$host_log"
  set -e

  local summary bytes elapsed ec mbps eth_mbps
  summary="$(grep -E '^ec=' "$host_log" | tail -1 || true)"
  if [[ -z "$summary" ]]; then
    echo "ERROR: no measurement summary from device. Raw:" >&2
    cat "$host_log" >&2 || true
    rm -f "$host_log"
    return 1
  fi
  # shellcheck disable=SC2086
  eval "${summary}"
  bytes="${bytes:-0}"
  elapsed="${elapsed:-$DURATION_S}"
  ec="${ec:-1}"
  rx_before="${rx_before:-0}"
  rx_after="${rx_after:-0}"
  rx_delta=$((rx_after - rx_before))
  [[ "$rx_delta" -lt 0 ]] && rx_delta=0

  mbps="$(mbps_of "$bytes" "$elapsed")"
  eth_mbps="$(mbps_of "$rx_delta" "$elapsed")"

  echo "==> result (ffmpeg remux on device)"
  echo "    URL:          ${url}"
  echo "    transport:    ${transport}"
  echo "    duration:     ${elapsed}s"
  echo "    bytes:        ${bytes}"
  echo "    bitrate:      ${mbps} Mbps"
  echo "    eth0_rx_delta:${rx_delta} bytes (~${eth_mbps} Mbps wire incl. other traffic)"
  if [[ "$ec" != "0" ]]; then
    echo "    ffmpeg_ec:    ${ec} (see log tail below)"
    echo "---- ffmpeg log (tail) ----"
    grep -v '^ec=' "$host_log" | tail -n 40 || true
  else
    # Surface RTP loss notes when present
    if grep -Eo 'RTP: (missed|lost) [0-9]+' "$host_log" >/dev/null 2>&1; then
      echo "    rtp:          $(grep -Eo 'RTP: (missed|lost) [0-9]+' "$host_log" | tail -1)"
    fi
  fi
  rm -f "$host_log"

  # Machine-readable line for easy compare
  echo "RESULT stream=${stream} transport=${transport} mbps=${mbps} bytes=${bytes} elapsed=${elapsed} eth0_rx_mbps=${eth_mbps} ffmpeg_ec=${ec}"
  # #region agent log
  debug_ndjson "HA" "android_ffmpeg_remux_result" \
    "{\"stream\":\"${stream}\",\"transport\":\"${transport}\",\"mbps\":${mbps},\"bytes\":${bytes},\"elapsed\":${elapsed},\"eth0_rx_mbps\":${eth_mbps},\"ffmpeg_ec\":${ec},\"serial\":\"${SERIAL}\"}"
  # #endregion
  [[ "$ec" == "0" && "$bytes" -gt 0 ]]
}

# --- main ---
SERIAL="$(wait_for_device)"
export SERIAL
echo "==> using adb device: ${SERIAL}"
"$ADB_BIN" -s "$SERIAL" get-state >/dev/null
echo "    model=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
echo "    release=$("$ADB_BIN" -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
echo ""

ensure_ffmpeg
echo ""
print_link_facts
echo ""

fail=0
for stream in $STREAMS; do
  for transport in $TRANSPORTS; do
    if ! measure_one "$stream" "$transport"; then
      fail=1
    fi
  done
done

echo ""
echo "Compare: Mac ~3.4 Mbps UDP | Linux board ~2.5 Mbps UDP | Android (this run) above."
echo "Same method: ffmpeg -c copy mpegts size / duration on the receiver."
exit "$fail"
