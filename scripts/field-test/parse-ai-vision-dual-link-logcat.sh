#!/usr/bin/env bash
# Parse AI Vision dual-link field test logcat.
#
# Usage:
#   adb -s DEVICE logcat -d | ./scripts/field-test/parse-ai-vision-dual-link-logcat.sh
#   ./scripts/field-test/parse-ai-vision-dual-link-logcat.sh build/field-test/.../logcat.txt
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'EOF'
Parses dual-link field test metrics from logcat.

Tags/lines:
  AiVisionDualLink: playback_first_frame, detect_session_start, detect_first_sample,
                    overlay_sync, dual_link_first_sample_gap_ms
  AiVisionResolutionProfile: detect_policy, live_rtsp_policy, playback_decode,
                               native_detect_decode
  AiVisionFragment: VIDEO_DISPLAYED, LIVE_VIDEO_SIZE, duplicate_rtsp=ai_vision_preview
  StreamDetect: sampled frame_id=... decode_ms=... detect_ms=... e2e_ms=...
EOF
  exit 0
fi

INPUT="${1:--}"

python3 - "$INPUT" <<'PY'
import re, sys, statistics

path = sys.argv[1]
if path == "-":
    text = sys.stdin.read()
else:
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()

playback_re = re.compile(
    r"playback_first_frame firstFrameMs=(?P<first>\-?\d+) decodeType=(?P<dec>\-?\d+)"
    r" size=(?P<w>\d+)x(?P<h>\d+) profile=(?P<profile>\S+)"
)
overlay_re = re.compile(
    r"overlay_sync frameId=(?P<fid>\d+) busToOverlayMs=(?P<ms>\d+) verdict=(?P<v>\S+)"
)
gap_re = re.compile(r"dual_link_first_sample_gap_ms=(?P<gap>\d+)")
native_re = re.compile(
    r"sampled frame_id=(?P<fid>\d+) .* decode_ms=(?P<dec>\d+) detect_ms=(?P<det>\d+) "
    r"e2e_ms=(?P<e2e>\d+)"
)
displayed_re = re.compile(
    r"VIDEO_DISPLAYED decodeType=(?P<dec>\-?\d+) firstFrameMs=(?P<first>\-?\d+)"
)
video_size_re = re.compile(r"LIVE_VIDEO_SIZE (?P<w>\d+)x(?P<h>\d+)")
duplicate_re = re.compile(r"duplicate_rtsp=ai_vision_preview")
detect_policy_re = re.compile(
    r"detect_policy weldNative=(?P<weld>\S+) aiVisionNative=(?P<ai>\S+) overlay=(?P<ov>\S+)"
)
playback_profile_re = re.compile(
    r"playback_decode size=(?P<w>\d+)x(?P<h>\d+) decodeType=(?P<dec>\-?\d+) profile=(?P<profile>\S+)"
)
native_profile_re = re.compile(
    r"native_detect_decode frameId=(?P<fid>\d+) size=(?P<w>\d+)x(?P<h>\d+)"
)
rtsp_policy_re = re.compile(r"live_rtsp_policy policy=(?P<policy>\S+)")

playbacks = playback_re.findall(text)
overlays = overlay_re.findall(text)
gaps = [int(x) for x in gap_re.findall(text)]
native_samples = native_re.findall(text)
displayed = displayed_re.findall(text)
sizes = video_size_re.findall(text)
duplicate = duplicate_re.search(text) is not None
detect_policies = detect_policy_re.findall(text)
playback_profiles = playback_profile_re.findall(text)
native_profiles = native_profile_re.findall(text)
rtsp_policies = rtsp_policy_re.findall(text)
fallback_mode = any(p[1] == "off" and p[2] == "off" for p in detect_policies)

print("=== AI Vision dual-link field test summary ===")
print(f"duplicate_rtsp=ai_vision_preview logged: {'yes' if duplicate else 'no'}")
print()

print("--- Resolution profile (AiVisionResolutionProfile) ---")
if detect_policies:
    p = detect_policies[-1]
    print(f"detect_policy weldNative={p[0]} aiVisionNative={p[1]} overlay={p[2]}")
    if p[1] == "off" and p[2] == "off":
        print("  mode=4.4_fallback (playback-only)")
else:
    print("(no detect_policy — enable isAiVisionResolutionProfileLoggingEnabled)")
if rtsp_policies:
    print(f"live_rtsp_policy last={rtsp_policies[-1]}")
if playback_profiles:
    w, h, dec, profile = playback_profiles[-1]
    print(f"playback_decode last={w}x{h} decodeType={dec} profile={profile}")
if native_profiles:
    fid, w, h = native_profiles[-1]
    print(f"native_detect_decode last frameId={fid} size={w}x{h} count={len(native_profiles)}")
elif fallback_mode:
    print("native_detect_decode skipped (4.4 fallback — expected)")
print()

print("--- Playback (AiVisionDualLink / AiVisionFragment) ---")
if playbacks:
    first_ms = [int(p[0]) for p in playbacks if int(p[0]) >= 0]
    dec_types = sorted({p[1] for p in playbacks})
    print(f"playback_first_frame count={len(playbacks)} decodeTypes={dec_types}")
    if first_ms:
        print(f"  firstFrameMs min={min(first_ms)} max={max(first_ms)} avg={statistics.mean(first_ms):.0f}")
else:
    print("(no AiVisionDualLink playback_first_frame — enable isAiVisionDualLinkFieldTestLoggingEnabled)")
if displayed:
    d0 = displayed[0]
    print(f"VIDEO_DISPLAYED first sample: decodeType={d0[0]} firstFrameMs={d0[1]}")
if sizes:
    w, h = sizes[-1]
    print(f"LIVE_VIDEO_SIZE last: {w}x{h}")
print()

print("--- Native detect (StreamDetect) ---")
if native_samples:
    decode = [int(s[1]) for s in native_samples]
    detect = [int(s[2]) for s in native_samples]
    e2e = [int(s[3]) for s in native_samples]
    print(f"samples={len(native_samples)}")
    print(f"  decode_ms avg={statistics.mean(decode):.0f} max={max(decode)}")
    print(f"  detect_ms avg={statistics.mean(detect):.0f} max={max(detect)}")
    print(f"  e2e_ms    avg={statistics.mean(e2e):.0f} max={max(e2e)}")
else:
    print("(no StreamDetect sampled frame_id lines)")
print()

print("--- Overlay sync (bus → UI, pass ≤300ms) ---")
if overlays:
    ms = [int(o[1]) for o in overlays]
    slow = sum(1 for o in overlays if o[2] == "slow")
    print(f"overlay_sync count={len(overlays)} slow={slow}")
    print(f"  busToOverlayMs avg={statistics.mean(ms):.0f} p95={sorted(ms)[int(len(ms)*0.95)-1 if len(ms)>1 else 0]} max={max(ms)}")
else:
    print("(no overlay_sync lines)")
print()

print("--- Dual-link first sample gap (playback vs detect mono) ---")
if gaps:
    print(f"gap_ms min={min(gaps)} max={max(gaps)} avg={statistics.mean(gaps):.0f}")
else:
    print("(no dual_link_first_sample_gap_ms)")
print()

print("--- Pass/fail hints (manual sign-off still required) ---")
ok = True
if displayed and displayed[0][0] != "1":
    print("WARN: playback decodeType != 1 (not MediaCodec hard decode)")
    ok = False
if overlays and max(int(o[1]) for o in overlays) > 300:
    print("WARN: overlay_sync exceeded 300ms")
    ok = False
if not duplicate and not fallback_mode:
    print("WARN: dual-link start not logged")
if not native_samples and not fallback_mode:
    print("WARN: no native detect samples")
    ok = False
elif fallback_mode and not native_samples:
    print("INFO: 4.4 fallback — native detect samples not expected")
print("AUTO_CHECK:", "PASS hints" if ok else "REVIEW required")
PY
