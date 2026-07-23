# AI Vision Dual-Link Field Test Record (fill on RK3566)

## Environment

| Field | Value |
|-------|-------|
| Date | |
| Tester | |
| Device serial | |
| App build / branch | |
| Camera IP | |
| IPC sub-stream resolution | |
| MediaMTX relay | yes / no |

## Flags

| Flag | Value |
|------|-------|
| `isNativeWeldStreamDetectEnabled` | |
| `isNativeAiVisionStreamDetectEnabled` | |
| `isAiVisionLiveDetectOverlayEnabled` | (derived) |
| `isAiVisionDualLinkFieldTestLoggingEnabled` | |
| `isAiVisionResolutionProfileLoggingEnabled` | (derived from field-test flag) |

## Automated capture

| Field | Value |
|-------|-------|
| Script output dir | `build/field-test/ai-vision-dual-link-...` |
| Duration (s) | |
| `summary.txt` AUTO_CHECK | |

## Metrics (from parser or manual)

| Metric | Value | Pass? |
|--------|-------|-------|
| Playback firstFrameMs | | < 3000 ms |
| decodeType | | = 1 |
| LIVE_VIDEO_SIZE | | |
| AiVisionResolutionProfile playback_decode | | |
| AiVisionResolutionProfile native_detect_decode | | (dual-link only) |
| detect_policy overlay=off | | (4.4 fallback) |
| detect_first_sample sinceSessionMs | | < 3000 ms |
| native decode_ms avg / max | | |
| native detect_ms avg / max | | |
| dual_link_first_sample_gap_ms | | |
| overlay_sync busToOverlayMs avg / max | | ≤ 300 ms |
| CPU / thermal notes | | |
| UI stutter (1–5, 1=smooth) | | ≤ 2 |

## Scenarios

| Scenario | Pass? | Notes |
|----------|-------|-------|
| S1 Dual-link start | | |
| S2 5 min preview + zoom | | |
| S3 Detect fail, playback continues | | |
| S4 Tab pause / stop | | |
| S5 Weld parallel (optional) | | |

## Verdict

- [ ] **PASS** — dual-link ready for production flag rollout
- [ ] **FAIL** — keep 4.4 fallback (`isNativeAiVisionStreamDetectEnabled` false); attach logcat path

Sign-off:
