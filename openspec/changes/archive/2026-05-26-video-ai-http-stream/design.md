## Context

- **Camera AI Vision (live):** `EasyPlayerClient` on PR1, `scheduleAiFrameSampling()` + `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms), preview det/cls, `DetectionOverlayView`, optional `CompositorFrameProvider` for **`CameraAiHttpPublisher`** (`GET /v1/camera/ai` chunked H.264 / TS).
- **Selected video (today):** `AiVisionFragment` batch-runs `buildOfflineInferenceTimeline` or `nativeInferVideoAndSave`, shows progress, then plays `files/ai-vision-inference-videos/…/*.mp4` or original + precomputed overlay fallback.

The user requires **parity**: selected recording behaves like live camera for **UI overlay** and **HTTP streaming**, while **still writing** the inference MP4 for upload (`AiVisionInferenceVideoUploadRunner`).

## Goals / Non-Goals

**Goals:**

- Start playback **immediately** on video select; overlay updates **during** playback at **`AI_VISION_PROCESS_VIDEO`** (200 ms) rate.
- **One shared encoded composited pipeline** for UI + HTTP subscribers.
- Write **`*.mp4.tmp`** during the session; **`rename`** to **`*.mp4`** only after successful mux finalize.
- `GET /v1/videos/:video_id/ai` = **live chunked stream** (same ergonomics as `/v1/camera/ai`), attaching to `ProcessVideoAiSession`.

**Non-Goals:**

- Changing `/v1/camera/ai` or PR1 live semantics.
- Cloud upload, WebSocket, TLS/auth.
- Replacing `/stream` raw file route.
- Batch-first UX (progress bar for entire file before any overlay) as the default path.

## Decisions

### 1. `ProcessVideoAiSession` (per video)

**Decision:** Introduce a session object keyed by business `videoId` + `AiVisionInferenceUploadStateStore.buildInferenceCacheKey(row, sourceFile)`.

| Responsibility | Owner |
|----------------|--------|
| Decode source MP4 (MediaExtractor + MediaCodec or shared decoder feeding compositor) | Session |
| Enable preview det/cls while session active (mirror live tab) | Session + `LensGuardManager` |
| Push sampled frames to LensGuard at `AI_VISION_PROCESS_VIDEO` (200 ms) | Session |
| UI composited H.264 preview (same fan-out as HTTP) | `ProcessVideoAiCompositedPreview` on `PlayerView` surface |
| Compositor → encoded AU fan-out | Session |
| Mux to `inferenceVideoFile(...).mp4.tmp` | Session |
| Reference count (Fragment surface, HTTP subscribers) | Session |

**Rationale:** Single ingest matches `CameraAiHttpPublisher` “one compositor per epoch” rule.

**Alternative:** Keep batch infer + stream finished file — **rejected** per product direction.

### 2. Playback UX in `AiVisionFragment`

**Decision:**

- On **Detect**: `session.start()` drives an **internal 1× playback clock** (source is decoded only inside the session for sampling/compose, not shown in the player).
- UI preview: **`ProcessVideoAiCompositedPreview`** subscribes to the same H.264 fan-out as `GET /v1/videos/:video_id/ai` and decodes to `PlayerView` (no `DetectionOverlayView` on source during an active session).
- **Replay** (post-EOS): ExoPlayer plays the finalized inference **`.mp4`** (same bytes as the live composited stream / upload artifact).
- Remove blocking whole-file progress as the default path; optional thin progress only for mux finalize if needed.

**Rationale:** One visible pipeline for in-app preview, LAN `ffplay`, and disk—simplifies cross-validation and debugging.

### 3. Disk write: `.mp4.tmp` → `.mp4`

**Decision:**

- Final path unchanged: `files/ai-vision-inference-videos/<owner>/ai-vision-inference-<owner>-<cacheKey>.mp4`.
- Muxer writes **`…mp4.tmp`** in the same directory.
- On **normal EOS** (decoder reached end): stop muxer, `fsync`, **`rename(tmp, mp4)`** (delete stale `mp4` first if replacing).
- On **cancel** / **force re-infer** / **cache key change**: stop session, **delete `.tmp`**, delete incomplete `mp4` if regenerating.
- Upload runner continues to use final **`mp4`** only when `length > 0`.

**Rationale:** LAN/HTTP never reads half-written `mp4`; atomic rename matches existing `exportInferenceVideoIfNeeded` tmp pattern.

### 4. HTTP: `ProcessVideoAiHttpPublisher`

**Decision:** Mirror `CameraAiHttpPublisher`:

- `GET /v1/videos/:video_id/ai` resolves row → starts or joins `ProcessVideoAiSession` → `acquire()` returns chunked `InputStream`.
- Headers: `Content-Type: video/H264` (default), optional `?format=ts`; `X-Video-Ai-Format`, `X-Video-Ai-Mode` (`composited` while inferring; `pass_through` only if compositor not yet ready—briefly relay source-encoded AU if design allows, else hold until first composited IDR like camera AI hot-switch).
- **503** only for: unknown `video_id`, missing source file, `LensGuard` unavailable, or session failed to start decode—not “file not ready”.
- `?force=1`: tear down session, delete tmp/mp4 for cache key, start fresh session.

**Rationale:** User explicitly asked to reuse **real-time** stream for LAN play (`ffplay` like `/v1/camera/ai`).

### 5. Deprecate batch offline as primary path

**Decision:** Remove `analyzeSelectedVideoOffline` whole-file loop as the default select path. Retain **timeline JSON cache** only if needed for upload metadata; overlay during play comes from **live session state**. `nativeInferVideoAndSave` **not** used for selected-video UX (optional internal optimization out of scope).

**Rationale:** Batch path contradicts real-time requirement.

### 6. Concurrency

**Decision:** At most one active `ProcessVideoAiSession` per `cacheKey`; second `video_id` with same file shares key; different videos serialize on RKNN via existing guards. HTTP + Fragment = refcount on same session.

### 7. Seek during session (v1)

**Decision:** While `ProcessVideoAiSession` is active, AI Vision **MUST NOT** allow user seek/scrub on the selected-video player (disable seek bar interaction or ignore seek requests). HTTP live stream has no seek semantics.

**Rationale:** Avoids inconsistent overlay, partial `.mp4.tmp`, and RKNN timeline resets. Seek support may be revisited in a later change (decoder seek + mux restart).

### 8. Audio (v1)

**Decision:** **No audio** on the recorded-video AI path: ExoPlayer plays **video track only**, inference MP4 mux is **video-only**, and `GET /v1/videos/:video_id/ai` carries **no audio** (aligned with `/v1/camera/ai`).

### 9. After end-of-stream (UI)

**Decision:** When the session playback clock reaches EOS, the UI **keeps the last composited frame** on screen (decoder surface) until idle. The app **MUST NOT** auto-start ExoPlayer replay. The user MAY tap **Replay** to play the finalized inference **`.mp4`** (same composited output) or **Re-detect**.

**Rationale:** Post-EOS idle and Replay both reference the same composited artifact as HTTP/upload.

### 10. HTTP when no active session (v1)

**Decision:** `GET /v1/videos/:video_id/ai` **always** starts or joins a **live** `ProcessVideoAiSession`. If no session is active (including after a prior run completed), a new request **MUST** start a **new** real-time session from the beginning. The route **MUST NOT** serve a completed inference `.mp4` as a static Range file in v1.

**Rationale:** Single mental model: `/ai` = live composited stream only. Completed files remain for in-app upload, not LAN file replay on this URL.

## Risks / Trade-offs

- **[Risk] MP4 decode + compositor + HTTP heavier than batch-once** → Mitigation: reuse camera compositor; single session; stop when refcount zero.
- **[Risk] Seek during real-time session** → Mitigation: v1 **disables seek** while session is active (see Decision 7).
- **[Risk] `camera-ai-http-stream` not merged** → Mitigation: implement publisher against `CameraHttpStreamPublisherCore` / compositor classes already in tree or land dependency first.
- **[Trade-off] No Range on live HTTP** → Clients use `ffplay`/`vlc` live mode; completed file available on disk for upload.

## Migration Plan

1. Implement `ProcessVideoAiSession` + tmp mux; unit tests for rename/cancel.
2. Refactor `AiVisionFragment` to session-based real-time UX.
3. Add `ProcessVideoAiHttpPublisher` + route.
4. Update docs; field-test `ffplay http://…/v1/videos/<id>/ai` alongside AI Vision UI.

Rollback: feature flag to old batch path if needed (not spec’d for v1).

## Resolved decisions (2026-05-26)

| Topic | v1 decision |
|-------|-------------|
| Seek | Disabled while session active |
| Audio | None (UI, mux, HTTP) |
| After EOS | Stay on source; user replay / re-infer; no auto-play inference MP4 |
| HTTP idle | Always start new live session; no static `.mp4` on `GET …/ai` |
