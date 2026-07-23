## 1. Process video lens_det data path (existing API)

- [x] 1.1 `ProcessVideoAiSession.runInferSample` calls `inferLensDetFromI420` with `source=process_video_lens_det` when `ENABLE_LENS_DET_APP`
- [x] 1.2 Use `tryAcceptLensDetProcessVideoInferSample()` before lens_det; reset gate on `start()` / `stop()`
- [x] 1.3 Record all lens_det outcomes (not only `hasTarget`) for timeline merge
- [x] 1.4 Logcat `process_video_lens_det` sample_ok / sample_fail per `sampleMs`

## 2. Timeline, persistence, SSE

- [x] 2.1 `ProcessVideoAiTimeline.Frame` optional `lensDet` snapshot
- [x] 2.2 Merge lens_det into frame in `runInferSample`; persist in `ProcessVideoAiTimelinePersistence`
- [x] 2.3 `AiInferenceSseJson.runningData` optional `lensDet` object; `publishRunning` passes result
- [x] 2.4 `ProcessVideoAiReplayJson` includes `lensDet` per frame when present
- [x] 2.5 Unit tests: persistence round-trip; SSE JSON contains `lensDet`

## 3. UI replay

- [x] 3.1 `AiVisionFragment` offline overlay prefers timeline `frame.lensDet`; session list fallback during active Detect
- [x] 3.2 Update `docs/OPENCV_DETECT_APP_INTEGRATION.md` — process video offline = lens_det (not zero_point)

## 4. Verification

- [x] 4.1 Build with `-PENABLE_LENS_DET_APP=true`; `make sync`; AI Vision Detect → logcat + timeline file `lensDet`
- [x] 4.2 Confirm no `ZeroPointCorrectionWriter` / Modbus from offline session
- [x] 4.3 `bash scripts/ci/verify-opencv-detect-integration.sh` after sync

## Out of scope (cancelled)

- ~~`inferZeroPointFromI420` on process video~~
- ~~SSE `zeroPoint` / timeline zero point fields for offline~~
