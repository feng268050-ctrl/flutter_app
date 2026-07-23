## Why

Live I420 inference (`guardedPushFrame` + `onCheckResult`) and offline JPG inference (`inferJpgToJson`) expose different Java APIs and in-memory shapes even though native detection JSON (`boxes`, `level`, `status`, `message`) is the same contract. Callers duplicate parsing (`AiVisionOverlayParser` vs `ProcessVideoAiTimeline`), and concurrent frame sampling can enqueue overlapping work without a single in-flight policy. A unified result type and two symmetric entry points in `LensGuardManager` reduce drift and make PR1 production inference and AI Vision recorded-video sessions easier to reason about.

## What Changes

- Add a unified immutable result type (e.g. `LensGuardInferenceResult`) with normalized detection fields. **`level` (int, 0/1/2 stain grade) and `status` (String, `CLEAN`/`MILD`/`HEAVY`) are mandatory on every result** for both I420 and JPG paths, alongside `success`, `code`, `message`, `imageWidth`, `imageHeight`, `boxes`, `source`, and `timestampMs`.
- Add `LensGuardManager.inferFromI420(...)` that pushes one I420 frame, waits for the matching `onCheckResult`, parses `message` JSON into `LensGuardInferenceResult`, and returns it (with timeout and error mapping).
- Add `LensGuardManager.inferFromJpg(...)` that calls the offline JSON path, maps/filters fields into the same `LensGuardInferenceResult` shape (no `classId`/`topk` cls-only fields in the unified object).
- Introduce a single in-flight gate: if a prior `inferFromI420` or `inferFromJpg` call has not completed, subsequent sampled frames SHALL be dropped (not queued) until the in-flight operation finishes; sampling gates continue to reject frames by interval, but accepted frames do not stack concurrent infer requests.
- Refactor PR1 production inference: background `inferFromI420` always for underlying lens-guard behavior; **burn boxes + status into PR1 frames and emit composited video only when `GET /v1/camera/ai` has active HTTP subscriber(s)**—without subscribers, only warnings/logs/alerts, no composited production video.
- Refactor `ProcessVideoAiSession` to use **background** `inferFromJpg` without blocking the composited playback clock. Hold-forward overlay: each completed sample’s `level`/`status`/`boxes` apply to that timestamp and all following frames until a newer sample completes, then update box coordinates for subsequent composited frames (in-app preview + HTTP `/v1/videos/:id/ai`).
- Apply the **same** background infer + hold-forward strategy to **AI Vision live RTSP** (`AI_VISION_LIVE`, 500 ms): do not block decode/display; **burn boxes and status text into the frame bitmap** with the same compositor as recorded video (no stacked `DetectionOverlayView` / status `TextView`); on-device preview and `GET /v1/camera/ai` share that composited pixels path.
- Deprecate direct use of `onI420Frame` + ad-hoc `inferJpgToJson` parsing at call sites; mark `inferJpgToJson` and unstructured push helpers as `@Deprecated` with migration notes pointing to the new APIs.
- **BREAKING (soft)**: New call sites MUST use unified APIs; deprecated methods remain for one release cycle with logging.

## Capabilities

### New Capabilities

- `lens-guard-unified-inference-result`: Unified detection result model, `inferFromI420` / `inferFromJpg` APIs, in-flight serialization, deprecation policy, and integration with production PR1, process-video, and AI Vision live inference.

### Modified Capabilities

- `production-ai-inference-stream-lifecycle`: Production sub-stream path SHALL use background `inferFromI420` with in-flight drop-when-busy semantics in addition to the 2000 ms sampling gate.
- `ai-frame-sampling-inference`: Document that accepted frames MAY be dropped when a unified infer operation is already in flight (orthogonal to interval gating); live `AI_VISION_LIVE` encode/display MUST NOT block on infer.
- `ai-vision-recorded-video-realtime`: `ProcessVideoAiSession` SHALL populate timeline from `inferFromJpg` + unified result, with hold-forward compositing during real-time file inference.
- `ai-vision-live-inference-overlay`: AI Vision live RTSP preview and `/v1/camera/ai` compositor SHALL use background unified infer and hold-forward overlay identical in policy to recorded-video real-time detect.
- `device-local-http-camera-ai`: Composited HTTP stream SHALL read hold-forward overlay from the same unified snapshot as on-device live preview (not a second parse path).
- `native-infer-image-contract`: App SHALL map native `nativeInferImageToJson` JSON into the unified result type; wire JSON schema unchanged at native boundary.
- `lens-guard-offline-infer-json`: Offline path SHALL prefer `inferFromJpg` returning unified results instead of raw JSON strings at feature boundaries.

## Impact

- **Java**: `LensGuardManager`, `NativeBridge` listener correlation (sequence/token for I420 wait), new result/parser types (likely under `com.lasercyber.lws.ai`), `ProductionInferenceStreamClient`, `ProcessVideoAiSession`, `ProcessVideoAiTimeline` adapter, `AiVisionFragment` overlay paths that today parse JSON directly.
- **Tests**: Unit tests for JSON normalization, in-flight drop, timeout; update instrumented smoke tests that call `inferJpgToJson` directly.
- **Native**: No JNI signature changes; `libai.so` contracts unchanged.
- **HTTP/UI**: `AiVisionFragment` live tab composites boxes into frame pixels (shared `ProcessVideoAiFrameRenderer`); retire stacked `DetectionOverlayView` for live det; `GET /v1/camera/ai` encodes same composited bitmaps. EventBus may remain for legacy production alerts only.
