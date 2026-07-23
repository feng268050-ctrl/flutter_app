#!/usr/bin/env bash
# Verify native artifacts staged for APK packaging (AI daemon runtimes + MediaMTX).
# P3: product APK must NOT require libai.so; AI runs via lws_ai_daemon spawn.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

APK="${1:-$repo_root/app/build/outputs/apk/staging/app-staging.apk}"
JNI_DIR="app/src/main/jniLibs/arm64-v8a"
MEDIAMTX_BIN="app/src/main/assets/mediamtx/arm64-v8a/mediamtx"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

for name in liblws_ai_daemon.so librknnrt.so libc++_shared.so libmpp.so; do
  path="$JNI_DIR/$name"
  [[ -f "$path" ]] || die "missing staged JNI lib: $path (run make ai)"
done
if [[ -f "$JNI_DIR/libai.so" ]]; then
  die "product jniLibs still contains libai.so (P3 removed); re-run make ai"
fi
echo "OK: staged daemon JNI libs under $JNI_DIR (no libai.so)"

[[ -f "$MEDIAMTX_BIN" ]] || die "missing MediaMTX binary: $MEDIAMTX_BIN (run make mediamtx)"
[[ -x "$MEDIAMTX_BIN" ]] || die "MediaMTX binary is not executable: $MEDIAMTX_BIN"
echo "OK: staged MediaMTX at $MEDIAMTX_BIN"

if [[ -f "$APK" ]]; then
  python3 - "$APK" <<'PY' || die "APK packaging check failed"
import sys, zipfile
apk = sys.argv[1]
need = [
    "lib/arm64-v8a/liblws_ai_daemon.so",
    "lib/arm64-v8a/librknnrt.so",
    "lib/arm64-v8a/libc++_shared.so",
    "lib/arm64-v8a/libmpp.so",
    "assets/mediamtx/arm64-v8a/mediamtx",
]
with zipfile.ZipFile(apk) as z:
    names = set(z.namelist())
missing = [e for e in need if e not in names]
if missing:
    print("ERROR: APK missing:", ", ".join(missing), file=sys.stderr)
    sys.exit(1)
if "lib/arm64-v8a/libai.so" in names:
    print("ERROR: APK still packages libai.so (P3 exit violated)", file=sys.stderr)
    sys.exit(1)
print("OK: APK contains daemon runtimes and MediaMTX (no libai.so):", apk)
PY
else
  echo "WARN: APK not found at $APK; skipped APK packaging check" >&2
fi
