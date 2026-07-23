#!/usr/bin/env bash
# Parse lens_det per-frame and session total timing from adb logcat dump.
# Usage:
#   adb -s DEVICE logcat -d | ./scripts/ci/parse-lens-det-timing-logcat.sh
#   ./scripts/ci/parse-lens-det-timing-logcat.sh /path/to/logcat.txt
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Parse lens_det timing from logcat.

Filters:
  PROCESS_VIDEO_AI_HTTP: process_video_lens_det sample_ok|sample_fail ms=... infer_ms=...
  PROCESS_VIDEO_AI_HTTP: process_video_lens_det timing ... total_infer_ms=... avg_infer_ms=...
  AiManager: inferLensDetFromI420 return ... infer_ms=...
EOF
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  INPUT="$1"
else
  INPUT="-"
fi

python3 - "$INPUT" <<'PY'
import re, sys

path = sys.argv[1]
if path == "-":
    text = sys.stdin.read()
else:
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()

lines = text.splitlines()

frame_re = re.compile(
    r"process_video_lens_det sample_(?P<outcome>ok|fail) ms=(?P<frame_ms>\d+) infer_ms=(?P<infer_ms>\d+)"
)
ai_re = re.compile(
    r"inferLensDetFromI420 return .* source=(?P<source>\S+) .* infer_ms=(?P<infer_ms>\d+)"
)
total_re = re.compile(
    r"process_video_lens_det timing reason=(?P<reason>\S+) samples=(?P<samples>\d+) "
    r"total_infer_ms=(?P<total>\d+) avg_infer_ms=(?P<avg>\d+)"
)
ts_re = re.compile(r"^(\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})")

frames = []
ai_calls = []
totals = []

for line in lines:
    ts_m = ts_re.match(line)
    ts = ts_m.group(1) if ts_m else ""
    m = frame_re.search(line)
    if m:
        frames.append({
            "ts": ts,
            "outcome": m.group("outcome"),
            "frame_ms": int(m.group("frame_ms")),
            "infer_ms": int(m.group("infer_ms")),
        })
        continue
    m = ai_re.search(line)
    if m:
        ai_calls.append({
            "ts": ts,
            "source": m.group("source"),
            "infer_ms": int(m.group("infer_ms")),
        })
        continue
    m = total_re.search(line)
    if m:
        totals.append({
            "ts": ts,
            "reason": m.group("reason"),
            "samples": int(m.group("samples")),
            "total_infer_ms": int(m.group("total")),
            "avg_infer_ms": int(m.group("avg")),
        })

print("=== lens_det 逐帧耗时 (process_video) ===")
if not frames:
    print("(无 process_video_lens_det sample_ok|sample_fail 日志)")
else:
    for i, f in enumerate(frames, 1):
        print(f"{i:3d}  frame_ms={f['frame_ms']:6d}  infer_ms={f['infer_ms']:4d}  {f['outcome']}  {f['ts']}")
    infer_vals = [f["infer_ms"] for f in frames]
    print(
        f"帧数={len(frames)}  sum_infer_ms={sum(infer_vals)}  "
        f"min={min(infer_vals)}  max={max(infer_vals)}  avg={sum(infer_vals)/len(infer_vals):.1f}"
    )

print()
print("=== lens_det 单次调用 (AiManager inferLensDetFromI420) ===")
if not ai_calls:
    print("(无 inferLensDetFromI420 infer_ms 日志)")
else:
    by_source = {}
    for c in ai_calls:
        by_source.setdefault(c["source"], []).append(c["infer_ms"])
    for src, vals in sorted(by_source.items()):
        print(
            f"source={src}  calls={len(vals)}  total_infer_ms={sum(vals)}  "
            f"avg={sum(vals)/len(vals):.1f}  min={min(vals)}  max={max(vals)}"
        )

print()
print("=== lens_det 会话汇总 (process_video_lens_det timing) ===")
if not totals:
    print("(无 timing reason=... total_infer_ms 日志 — 需等 Detect 会话结束 finalize)")
else:
    for t in totals:
        print(
            f"reason={t['reason']}  samples={t['samples']}  "
            f"total_infer_ms={t['total_infer_ms']}  avg_infer_ms={t['avg_infer_ms']}  {t['ts']}"
        )
PY
