## Context

Today:

- **Live**: `ProductionInferenceStreamClient` I420 callback → `LensGuardManager.onI420Frame` → `guardedPushFrame`. Results arrive asynchronously via `NativeListener.onCheckResult(level, status, message)`; UI/HTTP parse `message` with `AiVisionOverlayParser`.
- **Offline JPG**: `ProcessVideoAiSession` extracts JPEG → `inferJpgToJson` → `ProcessVideoAiTimeline.fromNativeJson`.
- Box JSON schema is native-owned and aligned (`boxes[]`, `imageWidth`/`imageHeight`, stain `level`/`status`/`message`), but Java types and call patterns differ.

Constraints:

- JNI / `libai.so` unchanged; no new native symbols required for v1.
- RKNN work stays on the existing single-thread executor in `NativeBridge`.
- Production weld sampling remains `PRODUCTION_WELD` (2000 ms); process video remains `AI_VISION_PROCESS_VIDEO` (200 ms).

## Goals / Non-Goals

**Goals:**

- One immutable `LensGuardInferenceResult` (name TBD in implementation) returned by `inferFromI420` and `inferFromJpg`.
- Centralize JSON parsing from `onCheckResult.message` and `nativeInferImageToJson` into one mapper.
- Serialize concurrent infer requests: at most one in-flight unified infer; drop newly sampled frames while busy.
- PR1 production path: decode callback stays fast; accepted samples submit work to a dedicated worker that calls `inferFromI420` and publishes overlay state from the unified result.
- Process-video session: use `inferFromJpg` with the same in-flight policy.

**Non-Goals:**

- Unifying **classification** (`nativeGetLastClsResult` / `LensClsSnapshotEvent`) into the same result type (det-only unified model for v1).
- Changing native JSON field names or adding synchronous native infer APIs.
- Replacing EventBus for lens-dirty production alerts (may still consume `onCheckResult` in parallel for legacy coordinators until migrated).
- Queueing multiple pending frames (explicitly rejected: drop when busy).

## Decisions

### 1. Unified result model (`LensGuardInferenceResult`)

Fields (all detection/stain oriented):

| Field | Type | Source |
|-------|------|--------|
| `success` | boolean | `code == 0` |
| `code` | int | native / mapped App errors |
| **`level`** | **int** | **Required. Stain grade `0/1/2` (clean/mild/heavy). From JSON root and/or `onCheckResult(int level, …)` on I420 path** |
| **`status`** | **String** | **Required. Short tag: `CLEAN`, `MILD`, `HEAVY` (map legacy `STAIN_MILD` / `STAIN_HEAVY` if native sends them). Same on I420 and JPG** |
| `message` | String | human text |
| `imageWidth`, `imageHeight` | int | JSON; 0 if unknown |
| `boxes` | `List<Box>` | normalized pixel coords + label/score/classId |
| `source` | String | e.g. `preview_det`, `offline_infer`, `production` |
| `timestampMs` | long | monotonic or wall; set at completion |
| `rawJson` | String optional | debug only, not required for UI |

`Box` mirrors existing parsers (x1,y1,x2,y2 pixel space before overlay normalization). Provide `toOverlayBoxes()` using same rules as `AiVisionOverlayParser` / `ProcessVideoAiTimeline`.

**`level` + `status` are first-class:** callers (production overlay, process-video timeline, upload gating) MUST read them from `LensGuardInferenceResult` only—not from parallel `LensCheckResultEvent` fields or raw JSON. Merge order: JSON in `message` wins when present; else I420 uses callback `level`/`status`; App errors use `level=-1`, `status=ERROR|BUSY`.

**Rationale:** Single type for compositor, timeline, and future features; avoids duplicating sanitize/corrupt-batch logic.

### 2. `inferFromI420(byte[] data, int width, int height)`

Flow:

1. If `inferInFlight` → return immediately with a **dropped** sentinel or `Optional.empty()` per API style (spec: caller treats as "no new work").
2. Set in-flight; copy I420 buffer (caller buffer may be recycled).
3. On RKNN thread: `guardedPushFrame`.
4. If push rejected → complete with error result, clear in-flight.
5. Else register one-shot waiter for next `onCheckResult` matching a generation token (ignore stale callbacks from earlier pushes).
6. Parse `message`: if JSON, use shared mapper; if plain text, populate `message`/`status` from callback args (`level`, `status` already on event).
7. Apply timeout (e.g. 5–8 s, tunable) → error result on timeout.
8. Clear in-flight; return `LensGuardInferenceResult`.

**Alternatives considered:**

- *Poll `nativeGetLastClsResult`* — wrong for det; rejected.
- *Queue frames* — user asked to drop; rejected.

### 3. `inferFromJpg(String imagePath)`

Flow:

1. Same in-flight gate (shared lock across I420 and JPG — one engine, one RKNN thread).
2. `guardedInferImageToJson` on RKNN thread (existing).
3. Map JSON → `LensGuardInferenceResult` via shared mapper; set `source` from JSON or `offline_infer`.
4. Clear in-flight; return.

Filter rules: drop cls-only fields; require `code` semantics per `native-infer-image-contract`; reuse corrupt-box sanitization from timeline parser (extract to shared util).

### 4. In-flight policy (global to `LensGuardManager`)

- Single `AtomicBoolean` or lock + generation counter.
- **Sampling gates unchanged**: `AiFrameSamplingGate` still limits accept rate.
- When gate accepts a frame but infer in-flight → **do not** start another infer; production worker logs at debug throttle.

**Process video (AI Vision recorded) — async hold-forward (non-blocking):**

```
Playback clock (15 fps) ──► always composite + mux + HTTP fan-out
                              │
                              ▼
                    overlay = findFrameAt(encodePosMs)  // latest completed sample ≤ pos
                              │
Sample scheduler (200 ms) ──► submit inferFromJpg async ──► onComplete: timeline.add(T, result)
                              │                              apply new boxes on subsequent ticks
                              └─ if infer in-flight: skip new sample; encode uses prior hold-forward
```

- **MUST NOT** block `encodeTickOnWorker` on `inferFromJpg`.
- Hold-forward: use latest completed `LensGuardInferenceResult` with `sampleTimeMs <= encodePos`; when a newer sample completes, update box coordinates for **subsequent** composited frames only (v1 does not remux past GOP).
- Before first result: source-only composite.
- Maps `LensGuardInferenceResult` → timeline `Frame`; keeps `findFrameAt` semantics.

**Production PR1:** async `inferFromI420` on worker; hold-forward result for monitoring; **frame compositing + H.264 fan-out only when `/v1/camera/ai` subscribers > 0**.

**AI Vision live RTSP (same policy as recorded video):**

| Aspect | Recorded (`ProcessVideoAiSession`) | Live (`AiVisionFragment`) |
|--------|-----------------------------------|---------------------------|
| Clock | Source timeline `encodePosMs` | Real-time display + compositor tick |
| Sample interval | 200 ms (`AI_VISION_PROCESS_VIDEO`) | 500 ms (`AI_VISION_LIVE`) |
| Infer API | `inferFromJpg` async | `inferFromI420` async (from TextureView bitmap → I420) |
| Hold-forward key | `findFrameAt(encodePosMs)` | `lastCompletedLiveResult` (monotonic time order) |
| Overlay sink | `ProcessVideoAiFrameRenderer` → composited bitmap → mux/preview | **Same renderer** → composited bitmap → on-screen surface + HTTP encoder |
| Stacked `DetectionOverlayView`? | **No** (inactive during composited detect) | **No** — boxes burned into frame pixels |
| Block stream? | **No** | **No** |

- Replace direct `onBitmapFrame` + EventBus + `DetectionOverlayView` with: sample → worker → `inferFromI420` → onComplete updates `lastLiveResult`.
- Each display/encode tick: `bitmap = textureView.getBitmap()` → `ProcessVideoAiFrameRenderer.drawFrame(composed, bitmap, holdForwardFrame)` → show `composed` (e.g. `ImageView`, `SurfaceView`/`TextureView` canvas blit, or local composited player) and feed HTTP compositor from the **same** composed bitmap.
- Hide or stop updating `DetectionOverlayView` and stain status `TextView` (`tvAiResult`, `tvAiState`) for composited live/recorded paths; **status text is drawn on the bitmap** by the shared compositor (extend `ProcessVideoAiFrameRenderer` or helper with a status banner from `displayMessage()` / `level`+`status`).
- Deprecate separate HTTP canvas `drawOverlay` when pre-composited bitmap is available.

**Quick / Engineer (production PR1):**

- Always (laser ON): background `inferFromI420` + hold-forward result for engine/alerts/logs.
- **Only when `GET /v1/camera/ai` has ≥1 subscriber:** run compositor encode on PR1 bitmaps with boxes + status burned in (same renderer as AI Vision).
- **No HTTP subscriber:** no composited video product; no on-device production UI that mimics HTTP overlay—warnings/logs/alerts only.

### 5. PR1 production integration

- `onI420Frame` becomes thin: sampling gate → if !inFlight, hand off to `productionInferExecutor` (single-thread, distinct from decode thread).
- Worker calls `inferFromI420` (which sets in-flight internally — avoid double-wrap).
- On success, update `CameraAiOverlayState` from result (same boxes as AI Vision).
- Deprecate direct `onI420Frame` public push for external callers; keep package-private or route through manager.

**Alternative:** Keep push in callback and only unify read path — rejected; user requested infer API on background thread.

### 6. Deprecations

| Deprecated | Replacement |
|------------|-------------|
| `LensGuardManager.inferJpgToJson` | `inferFromJpg` |
| `LensGuardManager.onI420Frame` (public) | `inferFromI420` or internal package API |
| Direct `ProcessVideoAiTimeline.fromNativeJson` at call sites | map from `LensGuardInferenceResult` |

Add `@Deprecated` + `Log.w` once per process for migration visibility.

### 7. Listener correlation for I420

`onCheckResult` may fire for preview_det, production stain, etc. Match using:

- Monotonic `pushGeneration` incremented per `inferFromI420` attempt.
- Optional: prefer messages with JSON `boxes` when preview det enabled; production messages without JSON still map `level`/`status`/`message`.

Stale callbacks (generation mismatch) ignored.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| `onCheckResult` never arrives → hung in-flight | Hard timeout; force clear in-flight; log stage marker |
| Wrong callback matched | Generation token; document preview vs production ordering |
| Stale overlay visible after slow infer | Expected: hold-forward shows last boxes until new sample completes; document UX |
| Blocking process-video encode | **Removed** — encode never awaits infer; only sample scheduler respects in-flight |
| Latency increase on PR1 | Already 2s sampling; one infer at a time matches product intent |
| Duplicate parsing logic during migration | Extract `LensGuardInferenceResultMapper` used by both paths |

## Migration Plan

1. Land `LensGuardInferenceResult` + mapper + unit tests (no call-site changes).
2. Implement `inferFromI420` / `inferFromJpg` + in-flight gate.
3. Switch `ProcessVideoAiSession` to `inferFromJpg`.
4. Switch production worker to `inferFromI420` + overlay update.
5. Deprecate old APIs; update tests/docs.
6. Follow-up change (optional): thin EventBus adapter from unified results only.

Rollback: feature flag `LensGuardManager.useUnifiedInference()` default true; false restores direct push + `inferJpgToJson` (keep deprecated methods implemented as wrappers during transition).

## Open Questions

- Exact timeout for I420 wait (5s vs 8s) — validate on RK3566 with preview_det enabled.
- Whether `inferFromI420` should return `Optional` vs result with `success=false` and `code=DROPPED_BUSY` for dropped frames — prefer explicit `code` for testability.
- Whether production non-JSON `onCheckResult` messages need `source=production` tag in unified result when JSON absent.
