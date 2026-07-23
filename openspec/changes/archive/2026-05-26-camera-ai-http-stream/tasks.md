## Phase A — Shared foundations (before `/ai` compositor)

- [x] A.1 Extract `CameraHttpStreamPublisherCore` from `CameraLiveHttpPublisher` (refcount, `LiveSubscriber`, queues, pass-through RTSP bootstrap, `EncodedVideoSink` fan-out, TS PSI prime)
- [x] A.2 Refactor `CameraLiveHttpPublisher` to delegate to core; run existing live route / publisher tests — **no behavior change** to `GET /v1/camera/live`
- [x] A.3 Add `CameraAiOverlayState` + `OverlayBox` model; move `preview_det` / `onCheckResult` box parsing out of `AiVisionFragment` into shared module with JVM unit tests
- [x] A.4 Wire `AiVisionFragment` `DetectionOverlayView` to `CameraAiOverlayState.getSnapshot()` (remove duplicate parsers from Fragment)

## Phase B — `GET /v1/camera/ai` pass-through (PR1, AI off)

- [x] B.1 Add `LogTAGConstant.CAMERA_AI_HTTP` and `CameraAiHttpPublisher` on top of `CameraHttpStreamPublisherCore` (`LIVE_INFERENCE_RTSP_URL`, pass-through only)
- [x] B.2 Implement AI-active signal helper (`LensGuardManager` + preview flags + `ProductionInferenceStreamClient` + AI Vision player streaming) — used later; compositor stays off in this phase
- [x] B.3 Register `GET /v1/camera/ai` in `DeviceLocalHttpServer` (`X-Camera-Ai-Format`, `X-Camera-Ai-Mode: pass_through`, `Cache-Control: no-cache`, 503 paths)
- [x] B.4 JVM/route tests: `DeviceLocalHttpCameraAiRouteTest`; publisher refcount; confirm **no** MediaCodec compositor started in pass-through-only scenarios

## Phase C — Composited stream + AI Vision frame reuse

- [x] C.1 Extract `LiveH264Encoder` from `AiVisionFragment` offline export patterns (≤15 fps, bounded bitrate, IDR on demand)
- [x] C.2 Implement `CompositorFrameProvider` interface + `AiVisionFragment` registration while preview player is active (weak/registry; unregister on stop/destroy)
- [x] C.3 Implement `CameraAiHttpCompositor` using `CameraAiOverlayState` + `LiveH264Encoder`; headless `HeadlessPr1FrameProvider` fallback when provider inactive
- [x] C.4 Wire `CameraAiHttpPublisher` mode machine: pass-through until first composited keyframe → hot switch → revert when AI overlay production stops; log `ai_http_switch`
- [x] C.5 Log `duplicate_rtsp=pr1_inference_active` / `duplicate_rtsp=ai_vision_preview` when fallback opens dedicated PR1 session

## Phase D — PR1 encoded-frame sharing (performance milestone)

- [x] D.1 Add `EncodedVideoSinkMultiplexer` (or multi-sink API) on `EasyPlayerClient`
- [ ] D.2 AI Vision preview `EasyPlayerClient`: optional encoded sink registration for LAN `/ai` pass-through subscribers
- [ ] D.3 Evaluate `ProductionInferenceStreamClient` encoded sink attachment without breaking I420 inference; implement or document limitation + keep duplicate RTSP log
- [ ] D.4 `CameraAiHttpPublisher` pass-through prefers multiplexer tap over dedicated PR1 when available

## Phase E — Tests, docs, field validation

- [x] E.1 JVM tests: mode state machine (pass_through ↔ composited), overlay snapshot immutability, TS mux via shared core
- [x] E.2 Document `GET /v1/camera/ai` in `docs/network-api-reference.md` (vs `/live`, mode header, hot switch, coexistence with AI Vision tab)
- [x] E.3 Add `docs/camera-http-ai-vision-integration.md` (or section in dual-stream doc): intersection diagram, phases, what is shared vs not shared with AI Vision
- [x] E.4 Field checklist: AI off → PR1 pass-through on `/v1/camera/ai`; AI Vision preview on → composited + boxes; Tab off + HTTP only → headless fallback; concurrent preview + HTTP → verify Phase D reduces duplicate RTSP
