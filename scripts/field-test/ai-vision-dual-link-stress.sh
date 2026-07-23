#!/usr/bin/env bash
# Capture RK3566 AI Vision dual-link stress test logs + resource samples.
#
# Usage:
#   ADB_SERIAL=<rk3566> DURATION_SEC=300 ./scripts/field-test/ai-vision-dual-link-stress.sh
#   ./scripts/field-test/ai-vision-dual-link-stress.sh <device_serial> [duration_sec]
#
# Before running on device:
#   1. Set CameraConfig.isNativeAiVisionStreamDetectEnabled() = true (dual-link)
#      or leave false for 4.4 playback-only fallback validation
#   2. Set CameraConfig.isAiVisionDualLinkFieldTestLoggingEnabled() = true
#   3. make sync, open Monitor → AI Vision (no selected process video), run 5+ min
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${1:-${ADB_SERIAL:-}}"
DURATION="${2:-${DURATION_SEC:-300}}"
OUT_DIR="${OUT_DIR:-${ROOT}/build/field-test/ai-vision-dual-link-$(date +%Y%m%d-%H%M%S)}"

if [[ -z "${DEVICE}" ]]; then
  DEVICE="$(adb devices | awk 'NR>1 && $2=="device"{print $1; exit}')"
fi
if [[ -z "${DEVICE}" ]]; then
  echo "No adb device. Set ADB_SERIAL or pass serial as arg1." >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
echo "Device: ${DEVICE}"
echo "Duration: ${DURATION}s"
echo "Output: ${OUT_DIR}"
echo
echo ">>> Clear logcat, then reproduce: AI Vision live preview (dual-link) for ${DURATION}s"
echo ">>> Press Ctrl+C early to stop capture."
echo

ADB=(adb -s "${DEVICE}")
LOG_FILE="${OUT_DIR}/logcat.txt"
TOP_FILE="${OUT_DIR}/top-samples.txt"
MEM_FILE="${OUT_DIR}/meminfo.txt"
THERMAL_FILE="${OUT_DIR}/thermal.txt"

"${ADB[@]}" logcat -c

(
  while true; do
    {
      echo "=== $(date -Iseconds) ==="
      "${ADB[@]}" shell top -n 1 -m 20 -s cpu 2>/dev/null | head -n 25
      echo
    } >> "${TOP_FILE}"
    sleep 10
  done
) &
TOP_PID=$!

(
  while true; do
    {
      echo "=== $(date -Iseconds) ==="
      "${ADB[@]}" shell dumpsys meminfo com.lasercyber.lws.ui 2>/dev/null | head -n 40
      echo
    } >> "${MEM_FILE}"
    sleep 30
  done
) &
MEM_PID=$!

(
  while true; do
    {
      echo "=== $(date -Iseconds) ==="
      "${ADB[@]}" shell cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || true
      echo
    } >> "${THERMAL_FILE}"
    sleep 30
  done
) &
THERMAL_PID=$!

cleanup() {
  kill "${TOP_PID}" "${MEM_PID}" "${THERMAL_PID}" 2>/dev/null || true
}
trap cleanup EXIT

"${ADB[@]}" logcat -v threadtime \
  AiVisionFragment:V \
  AiVisionDualLink:I \
  StreamDetect:I \
  StreamDetectOverlay:I \
  StreamDetectResultBus:I \
  EasyPlayerClientManger:I \
  2>&1 | tee "${LOG_FILE}" &
LOG_PID=$!

sleep "${DURATION}"
kill "${LOG_PID}" 2>/dev/null || true
wait "${LOG_PID}" 2>/dev/null || true

echo
echo ">>> Parsing logcat summary..."
"${ROOT}/scripts/field-test/parse-ai-vision-dual-link-logcat.sh" "${LOG_FILE}" | tee "${OUT_DIR}/summary.txt"
echo
echo "Done. Artifacts in ${OUT_DIR}"
