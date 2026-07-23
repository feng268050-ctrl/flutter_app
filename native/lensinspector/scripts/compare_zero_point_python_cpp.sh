#!/usr/bin/env bash
# Compare zero_point_infer (C++) vs find_redcode.py on the same video.
set -euo pipefail

VIDEO="${1:-/Users/ah0lic/Datasets/clean_zero/zero-3.mp4}"
ROI="${2:-/Users/ah0lic/Datasets/clean_zero/zero-5_center_circle_box.json}"
OUT_DIR="${3:-/tmp/zero_point_parity}"
CPP_BIN="${4:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY_SCRIPT="${PY_SCRIPT:-/Users/ah0lic/workspace/opencv_pet/find_redcode.py}"
PY="${PY:-/Users/ah0lic/workspace/opencv_pet/.venv/bin/python}"
if [[ ! -x "$PY" ]]; then
  PY=python3
fi

if [[ -z "$CPP_BIN" ]]; then
  for candidate in \
    "$ROOT/build-host/zero_point_infer" \
    "$ROOT/build/zero_point_infer"; do
    if [[ -x "$candidate" ]]; then
      CPP_BIN="$candidate"
      break
    fi
  done
fi

if [[ ! -x "$CPP_BIN" ]]; then
  echo "compare_zero_point_python_cpp: zero_point_infer not found; build with:" >&2
  echo "  cmake -S $ROOT -B $ROOT/build-host -DLIB_VERSION=v0.0.0 -DRKNN_RT_PATH=... && cmake --build $ROOT/build-host --target zero_point_infer" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
PY_JSON="$OUT_DIR/py_result.json"
CPP_JSON="$OUT_DIR/cpp_result.json"

"$PY" "$PY_SCRIPT" --video "$VIDEO" --roi-json "$ROI" --out-dir "$OUT_DIR/py" --center-box-expand-px 0 \
  >/dev/null 2>&1 || true
PY_OUT="$OUT_DIR/py/$(basename "${VIDEO%.*}")_zero_result.json"
if [[ -f "$PY_OUT" ]]; then
  cp "$PY_OUT" "$PY_JSON"
else
  echo "Python result missing: $PY_OUT" >&2
  exit 1
fi

"$CPP_BIN" --video "$VIDEO" --roi-json "$ROI" --out-dir "$OUT_DIR/cpp" >"$CPP_JSON"

"$PY" - <<'PY' "$PY_JSON" "$CPP_JSON"
import json, sys, math

py = json.load(open(sys.argv[1]))
cpp = json.load(open(sys.argv[2]))

def last_event(d):
    ev = d.get("events") or []
    return ev[-1] if ev else {}

pe = last_event(py)
ce = last_event(cpp)
pc = pe.get("detected_zero_xy") or py.get("detected_zero_xy")
cc = ce.get("detected_zero_xy") or cpp.get("detected_zero_xy")
po = pe.get("offset") or py.get("offset")
co = ce.get("offset") or cpp.get("offset")

if not pc or not cc:
    print("missing detected_zero_xy", pc, cc)
    sys.exit(2)

dx = abs(pc[0]-cc[0])
dy = abs(pc[1]-cc[1])
print(f"peak delta: dx={dx:.2f} dy={dy:.2f}")
if dx > 2 or dy > 2:
    print("FAIL peak > 2px")
    sys.exit(1)
if po and co:
    odx = abs(po.get("dx_px",0)-co.get("dx_px",0))
    ody = abs(po.get("dy_px",0)-co.get("dy_px",0))
    print(f"offset delta: ddx={odx:.3f} ddy={ody:.3f}")
    if odx > 0.01 or ody > 0.01:
        print("FAIL offset > 0.01px")
        sys.exit(1)
    if co.get("unit") != "px":
        print("FAIL cpp offset.unit != px")
        sys.exit(1)
print("OK parity within tolerance")
PY

echo "Parity OK: $PY_JSON vs $CPP_JSON"
