## 1. Temporal box reducer

- [x] 1.1 Add `LensStainBoxTemporalReducer` with `BOX_CLUSTER_TOLERANCE_PX = 10` and `MIN_PERSISTENT_OCCURRENCE_COUNT = 3` (retain when `count >= 3`)
- [x] 1.2 Implement expanded-rectangle clustering with distinct-frame occurrence counting and component-wise median canonical boxes
- [x] 1.3 Collect observed boxes from `ProcessVideoAiTimeline.Frame` (timeline `Box` list + stain-detect fallback bbox)
- [x] 1.4 Add unit tests: single-frame discard, 3-frame cluster keep, 2-frame discard, tolerance merge (±10 px), empty input, same-frame duplicate count-once

## 2. ProcessVideoAiSession integration

- [x] 2.1 Drain infer executor before reduction in `finalizeOnWorker` / `onPlaybackEnded` worker path
- [x] 2.2 Build temporal summary `ProcessVideoAiTimeline.Frame` (mark summary, map to `AiStainDetectResult`)
- [x] 2.3 Append summary frame to timeline; call `sseHub.publishRunning` **before** `publishSessionStop`
- [x] 2.4 Persist timeline including summary frame in `ProcessVideoAiTimelinePersistence`
- [x] 2.5 Add session-level test or hub test verifying SSE order: last `running` (summary) then `stop`

## 3. Overlay and replay

- [x] 3.1 Extend timeline lookup (e.g. `findTemporalSummaryFrame` or flag on `Frame`) for post-finalize overlay
- [x] 3.2 Update `AiVisionFragment` completion / Replay paths to prefer summary frame over per-frame hold-forward
- [x] 3.3 Optional: persist `temporalSummary: true` in timeline JSON for replay consumers

## 4. Alerts

- [x] 4.1 Publish one `LensCheckResultEvent` on main thread after summary (heavy if persistent boxes, clean otherwise)
- [x] 4.2 Ensure production weld deferred L001 still ignores offline source messages
- [x] 4.3 Add mapper/publisher test for summary clean vs dirty outcomes

## 5. Verification

- [x] 5.1 Manual: Detect process video with transient boxes only → no alert, no boxes on replay
- [x] 5.2 Manual: Detect with stable contamination → summary SSE before stop, alert dialog, replay shows summary boxes
- [x] 5.3 Run affected unit tests (`LensStainBoxTemporalReducer*`, `ProcessVideoAi*`, `AiInferenceSseHub*`)

## 6. Remove AI Vision hold-forward overlay

- [x] 6.1 Recorded video: `resolveRecordedVideoBoxFrame` / `updateOfflineInferenceOverlay` use `findFrameAt` only; remove `findLastFrameWithDetectionAt` and `findLastStainDetectWithTargetAt` overlay paths
- [x] 6.2 Live RTSP: remove `OpencvStainDetectHoldForwardStore` write/read from `AiVisionFragment`; `updateLiveInferenceOverlay` shows latest completed stain sample only, clears on no-box sample
- [x] 6.3 Live RTSP: adjust `runLiveInferSampleOnce` to refresh overlay on clean samples (clear stain boxes)
- [x] 6.4 Deprecate or remove `ProcessVideoAiTimeline.findLastFrameWithDetectionAt` if no remaining callers; update/remove hold-forward unit tests
- [x] 6.5 Update `ProcessVideoAiSession.findLastStainDetectWithTargetAt` usages (remove from AI Vision overlay only)
- [x] 6.6 Manual: during Detect, transient box disappears on next no-box sample; Live preview does not keep stale boxes after clean sample
