#!/usr/bin/env bash
# Verify OpenCV detect end-to-end integration artifacts (libai JNI + optional APK DEX).
#
# Usage:
#   scripts/ci/verify-opencv-detect-integration.sh
#   scripts/ci/verify-opencv-detect-integration.sh /path/to/app.apk
#
# Env:
#   LIBAI_SO   — default native build_android/libai.so (host/tests; not staged in product APK)
#   ADB_SERIAL — optional adb target (logcat recipe only when --logcat-hints)
#
# See docs/OPENCV_DETECT_APP_INTEGRATION.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIBAI_SO="${LIBAI_SO:-$ROOT/native/lensinspector/build_android/libai.so}"
VERIFY_JNI="$ROOT/native/lensinspector/scripts/verify_libai_jni.sh"
APK="${1:-}"

# Java/DEX symbols for product daemon path (P3).
DEX_REQUIRED=(
  AiDaemonSupervisor
  offlineOpencvStainFromNv12
  offlineOpencvStainFromJpg
  ZeroPointDetectCoordinator
  ZeroPointDetectJson
  OpencvDetectCodes
  AiManager
  StreamDetectResultBus
)

# Deprecated product symbols that must NOT appear.
DEX_FORBIDDEN=(
  LensGuardManager
)

usage() {
  cat <<'EOF'
Usage:
  scripts/ci/verify-opencv-detect-integration.sh [app.apk]

Checks:
  1) libai.so exports required OpenCV/RKNN JNI (verify_libai_jni.sh)
  2) If APK given: DEX contains current symbols; no deprecated LensGuard/zero-point names

Logcat acceptance (manual, on device):
  adb logcat -c
  adb logcat -v time -s ZeroPointDetect:I ZeroPointCorrection:I LensDetDetect:I AiManager:I PROCESS_VIDEO_AI_HTTP:I

Process video Detect (offline lens_det, ENABLE_LENS_DET_APP=true):
  PROCESS_VIDEO_AI_HTTP: process_video_lens_det sample_ok|sample_fail ms=...
  timeline JSON under files/.../inference_timeline.json with per-frame "lensDet" object

Expected after app start:
  ZeroPointDetect: attached roi=...
  AiManager: Engine started

Expected after laser OFF->ON (engineer mode, >=2s):
  ZeroPointDetect: task_start eventId=...
  ZeroPointDetect: sample_ok / skip_sample / detect_result module=zero_point code=... reason=...

Docs: docs/OPENCV_DETECT_APP_INTEGRATION.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

echo "==> verify libai JNI: $LIBAI_SO"
if [[ ! -f "$LIBAI_SO" ]]; then
  echo "ERROR: libai.so not found. Run 'make ai' first." >&2
  exit 1
fi
bash "$VERIFY_JNI" "$LIBAI_SO"

if [[ -z "$APK" ]]; then
  echo "OK: libai JNI verified (no APK path; skip DEX check)"
  echo "TIP: pass APK path to verify DEX symbols, or run after 'make build'"
  exit 0
fi

if [[ ! -f "$APK" ]]; then
  echo "ERROR: APK not found: $APK" >&2
  exit 1
fi

command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip required" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q "$APK" 'classes*.dex' -d "$TMP"

DEX_BLOB="$TMP/dex_strings.txt"
: > "$DEX_BLOB"
shopt -s nullglob
for dex in "$TMP"/classes*.dex; do
  strings "$dex" >> "$DEX_BLOB"
done
shopt -u nullglob

missing_dex=()
for sym in "${DEX_REQUIRED[@]}"; do
  if ! grep -qF "$sym" "$DEX_BLOB"; then
    missing_dex+=("$sym")
  fi
done

found_forbidden=()
for sym in "${DEX_FORBIDDEN[@]}"; do
  if grep -qF "$sym" "$DEX_BLOB"; then
    found_forbidden+=("$sym")
  fi
done

if [[ ${#missing_dex[@]} -gt 0 ]]; then
  echo "ERROR: APK DEX missing required symbol(s):" >&2
  for m in "${missing_dex[@]}"; do
    echo "  - $m" >&2
  done
  echo "Run 'make sync' to install Java layer. See docs/OPENCV_DETECT_APP_INTEGRATION.md" >&2
  exit 1
fi

if [[ ${#found_forbidden[@]} -gt 0 ]]; then
  echo "ERROR: APK DEX still contains deprecated symbol(s):" >&2
  for f in "${found_forbidden[@]}"; do
    echo "  - $f" >&2
  done
  exit 1
fi

# Process-video offline lens_det path (ai-vision-offline-lens-det); must not wire zero_point offline.
offline_lens_det_markers=(
  process_video_lens_det
)
for sym in "${offline_lens_det_markers[@]}"; do
  if ! grep -qF "$sym" "$DEX_BLOB"; then
    echo "ERROR: APK DEX missing process-video lens_det marker: $sym" >&2
    echo "Rebuild with: ./gradlew :app:assembleDebug -PENABLE_LENS_DET_APP=true" >&2
    exit 1
  fi
done

PROCESS_VIDEO_SESSION="$ROOT/app/src/main/java/com/lasercyber/lws/ui/common/ai/video/ProcessVideoAiSession.java"
forbidden_pv=(
  ZeroPointCorrectionWriter
  ZeroPointDetectCoordinator
  inferZeroPointFromI420
)
for sym in "${forbidden_pv[@]}"; do
  if grep -qF "$sym" "$PROCESS_VIDEO_SESSION"; then
    echo "ERROR: ProcessVideoAiSession must not reference $sym (offline zero_point out of scope)" >&2
    exit 1
  fi
done

echo "OK: APK DEX OpenCV detect symbols verified ($APK)"
echo "OK: process-video offline lens_det markers present; no zero_point wiring in ProcessVideoAiSession"
echo "Next: deploy with 'make sync' and check logcat (see --help)"
