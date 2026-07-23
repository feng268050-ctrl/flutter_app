## 1. ProcessVideoAiSession (core)

- [x] 1.1 Add `ProcessVideoAiSession` with cache key, refcount, decode source MP4, `AI_VISION_LIVE` sampling, preview det/cls lifecycle
- [x] 1.2 Integrate compositor + encoded AU fan-out (reuse `CameraAiHttpCompositor` / `CameraHttpStreamPublisherCore` patterns from camera AI HTTP)
- [x] 1.3 Mux composited output to `…mp4.tmp`; finalize with atomic rename to `…mp4` on EOS; delete tmp on cancel/`force`
- [x] 1.4 Expose overlay/frame state for UI (`DetectionOverlayView` at playback position) and session status for upload gating

## 2. AI Vision Fragment

- [x] 2.1 Replace batch `analyzeSelectedVideoOffline` default path with session start on video select
- [x] 2.2 Composited H.264 preview on `PlayerView` (same fan-out as HTTP); internal session playback clock; no source+overlay during detect
- [x] 2.3 Wire manual re-infer, replay (ExoPlayer on `.mp4`), EOS last composited frame, cancel, leave-tab refcount
- [x] 2.4 Keep upload button disabled until finalized `.mp4` exists

## 3. HTTP

- [x] 3.1 Add `ProcessVideoAiHttpPublisher` + route `GET /v1/videos/:video_id/ai` (H.264 default, `?format=ts`, `X-Video-Ai-Format`, `X-Video-Ai-Mode`)
- [x] 3.2 Join or start `ProcessVideoAiSession` per request; support `?force=1`
- [x] 3.3 Tests: route headers, shared session with publisher mock, 404/503 cases

## 4. Docs and verification

- [x] 4.1 Update `docs/network-api-reference.md` (live stream like `/v1/camera/ai`, ffplay examples, not 503 poll)
- [ ] 4.2 Device: Detect in AI Vision → composited preview matches `ffplay http://<ip>:8080/v1/videos/<id>/ai`
- [ ] 4.3 After EOS: `.mp4` present, `.tmp` absent; upload succeeds
