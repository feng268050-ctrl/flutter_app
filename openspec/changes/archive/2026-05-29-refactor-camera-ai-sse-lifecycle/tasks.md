## 1. SSE hub, clocks, and JSON payloads

- [x] 1.1 Add `TimestampClock` interface with `ConnectionRelativeClock` (camera) and `MediaTimelineClock` (process video); inject into `AiInferenceSseHub`
- [x] 1.2 Add `AiInferenceSseJson.idleData`, `startData`, `stopData`, `runningData` (unified; no `streamTimeMs`)
- [x] 1.3 Replace `heartbeat` with `idle` (15 s interval, `timestampMs` + `inferenceActive`) on all hub instances
- [x] 1.4 On `acquireSubscriber()`: enqueue immediate `idle` (`timestampMs: 0`) before returning
- [x] 1.5 Rename `inference` → `running` in all hub publish paths (camera + process video)

## 2. Camera session lifecycle

- [x] 2.1 Add `CameraAiSseSessionState` on `CameraAiHttpPublisher` (sessionId, source, connection-relative start time)
- [x] 2.2 Implement `onInferenceSessionStart` / `onInferenceSessionStop` → broadcast `start`/`stop`; replay `start` to new subscriber if session active
- [x] 2.3 Wire `ProductionInferenceStreamClient.start()` / `stop()` (`production_weld`, `laser_off`, `stream_error`, `release`)
- [x] 2.4 Wire `AiVisionFragment` live infer enable/disable (`ai_vision_live`, `preview_stopped`)
- [x] 2.5 Update `CameraAiHttpPublisher.publish()` to emit `running` with `sessionId` and connection-relative `timestampMs`

## 3. Process video session lifecycle

- [x] 3.1 Emit `start` when `ProcessVideoAiSession` begins processing (`source` `process_video`, `samplingIntervalMs` `500`)
- [x] 3.2 Emit `stop` on EOS (`session_complete`), cancel (`session_cancelled`), `force=1` (`force_restart`), error (`stream_error`), release
- [x] 3.3 Update `publishInference` path to `running` with media-timeline `timestampMs` from session playback position
- [x] 3.4 Mid-connection join: replay `start` after `idle` when session already running; `inferenceActive` on `idle` reflects session state

## 4. Tests

- [x] 4.1 Update `AiInferenceSseJsonTest` for new payload helpers
- [x] 4.2 Update `CameraAiLiveSseTimelineTest` for `running`, `sessionId`, connection-relative clock
- [x] 4.3 Add process-video timeline test: `idle` first, `start` at 0, `running` at media ms, `stop` at EOF
- [x] 4.4 Add tests: immediate `idle`, `start`/`stop` sequences, mid-connection `start` replay (both routes)
- [x] 4.5 Update `AiInferenceSseHubFlushTest` and `DeviceLocalHttpCameraAiRouteTest`

## 5. Documentation

- [x] 5.1 Update `docs/network-api-reference.md` for **both** `/v1/camera/ai` and `/v1/videos/:id/ai` (unified event table, `timestampMs` semantics per route, remove `heartbeat`/`inference`/`streamTimeMs`)
