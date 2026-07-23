## Context

The HMI already exposes **`GET /v1/camera/live`** (`CameraLiveHttpPublisher`): reference-counted **PR0** RTSP ingest, **`EncodedVideoSink`** pass-through (Annex-B H.264 default, optional MPEG-TS), no display decode for HTTP.

AI Vision and production inference use **PR1** (`CameraConfig.LIVE_INFERENCE_RTSP_URL`):

- **`AiVisionFragment`**: `EasyPlayerClient` → `TextureView` + `DetectionOverlayView` / AI status overlay; `LensGuardManager` receives **TextureView bitmap samples** (`pushAiVisionPreviewFrame`) at `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms).
- **`ProductionInferenceStreamClient`**: separate PR1 client, virtual `Surface`, I420 decode for weld inference (2 s sampling).

There is **no** existing encoded-bitstream tap for “video + texture + boxes” — only UI compositing and offline export (`MediaCodec` in `AiVisionFragment`).

Stakeholders: LAN mobile/tools (same as `/v1/camera/live`). Constraint: RK3588 tablet; avoid a **second** full 1080p decode per HTTP viewer and avoid starting heavy encode when nobody is watching.

## Goals / Non-Goals

**Goals:**

- Add **`GET /v1/camera/ai`** on port **8080**, parallel API shape to `/v1/camera/live` (`format=h264|ts`, chunked body, `Cache-Control: no-cache`, 503 errors, max subscribers).
- **Default / AI-off:** relay **PR1** encoded access units (pass-through, no re-encode).
- **AI-on:** relay **composited** H.264 (camera + inference overlay texture/boxes) on the **same URL and connection**, switching as soon as the first composited keyframe is available.
- **Performance:** one shared ingest per publisher epoch; pass-through MUST NOT decode to YUV; compositor encode runs **only** while `subscriberCount > 0` and AI overlay pipeline is active.
- **Coexistence:** prefer sharing PR1 encoded tap with an existing player when feasible; otherwise one dedicated PR1 session with `duplicate_rtsp` logging.

**Non-Goals:**

- PR0 on this route; cloud/TLS/auth; WebSocket.
- Forcing AI Vision tab visible for HTTP clients.
- Full-frame-rate re-encode at 25 fps when 10–15 fps suffices for remote view.
- Native libai API changes in v1 (follow-up if composited H.264 export is added upstream).

## Decisions

1. **Route and response shape**

   **Decision:** Mirror `/v1/camera/live`:

   - `GET /v1/camera/ai` → 200 chunked; default `Content-Type: video/H264`, `X-Camera-Ai-Format: h264`.
   - `?format=ts` → `video/mp2t`, `X-Camera-Ai-Format: ts`.
   - Optional response header **`X-Camera-Ai-Mode`**: `pass_through` | `composited` (updated when mode changes mid-stream).

   **Rationale:** Clients reuse ffplay/VLC/Flutter patterns from live docs.

2. **Publisher — `CameraAiHttpPublisher`**

   **Decision:** Singleton delegating pass-through and subscriber management to **`CameraHttpStreamPublisherCore`** (see Shared abstractions §1). `/ai`-specific logic: PR1 URL, mode state machine, compositor attach/detach, `X-Camera-Ai-Mode`.

   Internal **mode state machine:**

   | Mode | Condition | Data source |
   |------|-----------|-------------|
   | `PASS_THROUGH` | No composited frames available | PR1 `EncodedVideoSink` |
   | `COMPOSITED` | Compositor produced keyframe | `CameraAiHttpCompositor` encoded sink |

   **Rationale:** Centralizes lifecycle; HTTP handler stays thin.

3. **When AI is considered “active” for composited mode**

   **Decision:** `LensGuardManager.isRunning()` **and** at least one of:

   - AI Vision preview classification or detection enabled (`setAiVisionPreview*`), **or**
   - `ProductionInferenceStreamClient.isStreaming()` (laser-on weld path), **or**
   - `AiVisionFragment` preview player is actively streaming PR1/PR0 for the tab.

   While AI is inactive, publisher stays in **`PASS_THROUGH`** only.

   **Rationale:** Matches operator expectation (“AI inference started”); preview and production paths both imply overlay/metadata flow.

4. **Pass-through path (performance-critical)**

   **Decision:** Same technique as live:

   - `EasyPlayerClient` on `LIVE_INFERENCE_RTSP_URL`, TCP, virtual `Surface`, **`setEncodedPassThroughOnly(true)`**, **`EncodedVideoSink`** → fan-out (raw H.264 or `MpegTsMuxer`).

   **Coexistence:**

   1. If `CameraAiHttpPublisher` is the only PR1 HTTP consumer and no other client holds PR1, use dedicated ingest.
   2. If `ProductionInferenceStreamClient` or AI Vision player already holds PR1, v1 MAY use a second session and MUST log `duplicate_rtsp=pr1_inference_active` or `duplicate_rtsp=ai_vision_preview` (shared encoded tap is a follow-up).

   **Rationale:** User requirement “未启动则直接推 PR1” with minimal burden.

5. **Composited path (AI-on)**

   **Decision (v1):** Introduce **`CameraAiHttpCompositor`** — headless pipeline active only when `subscriberCount > 0` **and** AI-active signal is true:

   - **Input:** Latest overlay state from `LensGuardManager` listener (`onCheckResult` / preview_det JSON boxes) plus a **single** decoded frame source:
     - **Preferred:** Reuse decode from the active AI Vision `EasyPlayerClient` when the tab is visible (register a weak `CompositorFrameProvider` from `AiVisionFragment`).
     - **Fallback:** Dedicated PR1 decode to virtual surface **only while compositor is active** (stop when last subscriber leaves or AI turns off).
   - **Processing:** Draw boxes/status texture on `Canvas` / GLES into encoder input (same visual rules as `DetectionOverlayView` + `layoutAiOverlay`, not necessarily pixel-identical in v1).
   - **Output:** One shared **`MediaCodec` H.264** encoder (Baseline, bounded bitrate, **≤15 fps** target) feeding `EncodedVideoSink`-compatible callbacks into the publisher fan-out.

   **Hot switch:** Publisher continues writing PR1 pass-through until compositor emits first **keyframe**; then atomically switch all subscribers to compositor queue; log `ai_http_switch pass_through→composited`. Reverse switch when AI stops: after last compositor frame, revert to pass-through on next IDR from PR1.

   **Alternatives rejected:**

   - **TextureView.getBitmap per frame at 25 fps** — too heavy for RK3588 when multiple subscribers.
   - **Always encode** — violates performance goal when AI off.
   - **Separate URL for composited** — violates user requirement for seamless switch.

6. **HTTP handler**

   **Decision:** `DeviceLocalHttpServer` dispatches `GET /v1/camera/ai` like `serveCameraLive`, calling `CameraAiHttpPublisher.getInstance().acquire(...)`, `Connection: close`, disconnect `release()`.

7. **Threading and logging**

   **Decision:** Tag `CAMERA_AI_HTTP` (add to `LogTAGConstant`). RTSP/compositor on background threads; per-subscriber queues on publisher lock.

## Intersection with AI Vision (and `/v1/camera/live`)

**Scope clarification:** **`GET /v1/camera/live` and `GET /v1/camera/ai` remain separate routes** (PR0 vs PR1, different client use cases). This section covers **shared implementation** with AI Vision and incidental overlap with the existing live publisher—not route consolidation.

### What overlaps today

| Concern | `GET /v1/camera/live` | `GET /v1/camera/ai` | AI Vision (`AiVisionFragment`) |
|--------|------------------------|---------------------|--------------------------------|
| RTSP profile | PR0 (`RECORDING_RTSP_URL`) | PR1 (`LIVE_INFERENCE_RTSP_URL`) | PR1 first, PR0 fallback |
| LAN output | Encoded pass-through → HTTP | Pass-through **or** composited encode → HTTP | None (on-screen only) |
| Decode | Avoided for HTTP | Avoided in pass-through; required for composited | Always (→ `TextureView`) |
| Inference | — | Consumes results, does not re-run inference | `pushAiVisionPreviewFrame` (500 ms bitmap) |
| Overlay UI | — | Must draw same boxes/labels as preview | `DetectionOverlayView` + `layoutAiOverlay` |
| Overlay data | — | `onCheckResult` / `preview_det` JSON | Same events, parsed in Fragment |
| Encoder | — | `CameraAiHttpCompositor` (planned) | Offline export `MediaCodec` in Fragment |
| Other PR1 consumer | — | Competes with | `ProductionInferenceStreamClient` (I420, 2 s) |

**Functional intersection (AI Vision ↔ `/ai`):** operators expect the HTTP AI stream to look like the AI Vision tab—same sub-stream, same detection boxes and status texture, driven by the same `LensGuardManager` events. **Technical intersection:** both need PR1 imagery and overlay state; only HTTP additionally needs a continuous **encoded** byte stream.

**Non-intersection (do not force shared UI pipeline):** HTTP must not route through `TextureView` or run full-rate `getBitmap` for inference (that path stays 500 ms for `LensGuardManager`). AI Vision must keep low-latency direct Surface decode and existing retry/session logic.

### What overlaps with `/v1/camera/live` (infrastructure only)

Both LAN endpoints share: `LiveFormat`, `MpegTsMuxer`, `EncodedVideoSink` relay, virtual `Surface` + `setEncodedPassThroughOnly`, subscriber queues/backpressure, `prepareCameraNetwork()`, 503 semantics. They differ only in **RTSP URL**, **response headers** (`X-Camera-Live-Format` vs `X-Camera-Ai-Format` / `X-Camera-Ai-Mode`), and `/ai`-specific mode switching + compositor.

## Shared abstractions (implementation building blocks)

Introduce package-local types under `.../network/http/local/` (names may adjust during apply; responsibilities are normative for this change).

### 1. `CameraHttpStreamPublisherCore` (Phase A — before `/ai` feature-complete)

**Responsibility:** Extract from `CameraLiveHttpPublisher` without behavior change to live route:

- `acquire` / `release` refcount and subscriber list (`LiveSubscriber`, bounded queue, drop-oldest).
- `ensurePassThroughIngest(rtspUrl, format, EncodedVideoSink fanOut)` — virtual Surface, first-frame latch, teardown.
- Shared `buildEncodedFanOutSink(format, muxer, subscribers)` and TS PSI prime.
- Hooks: `logTag()`, optional `onIngestStarted` / `onIngestStopped` for diagnostics.

**Consumers:**

- `CameraLiveHttpPublisher` — thin wrapper: `rtspUrl = RECORDING_RTSP_URL`, live headers only.
- `CameraAiHttpPublisher` — wrapper: `rtspUrl = LIVE_INFERENCE_RTSP_URL`, plus mode state machine and compositor source selection.

**Not in core:** compositor, AI-active detection, `X-Camera-Ai-Mode`, overlay drawing.

### 2. `CameraAiOverlayState` (Phase A — parallel with core extract)

**Responsibility:** Single source of truth for overlay **data** (not View hierarchy):

- Parse `preview_det` and production-style `onCheckResult` messages into normalized `OverlayBox` list + status text (move logic out of `AiVisionFragment` private parsers where possible).
- Thread-safe `getSnapshot()` for compositor thread and main-thread `DetectionOverlayView`.
- Register updates from existing `LensGuardManager` listener path (one subscription; Fragment and HTTP compositor both read snapshots).

**Consumers:**

- `AiVisionFragment` — `DetectionOverlayView` reads snapshot instead of duplicating `parseBoxes`.
- `CameraAiHttpCompositor` — draws from same snapshot (functional parity with UI; pixel-perfect optional in v1).

**Explicit non-goal:** Fragment does not depend on HTTP types.

### 3. `CompositorFrameProvider` (Phase B)

**Responsibility:** Optional registry of decoded-frame suppliers for composited encode:

```text
interface CompositorFrameProvider {
  boolean isActive();
  int getWidth();
  int getHeight();
  // Latest frame for encode: Surface, Image, or NV12 buffer — implementation-defined
}
```

- **`AiVisionFragment` implementation:** registered while preview player is streaming and tab is started; unregistered on stop/destroy. Preferred frame source when active → **no extra PR1 decode** for HTTP compositor.
- **`HeadlessPr1FrameProvider` fallback:** owned by `CameraAiHttpCompositor` only when provider inactive but HTTP subscribers + AI-active.

### 4. `LiveH264Encoder` (Phase B — optional but recommended)

**Responsibility:** Shared MediaCodec H.264 encoder wrapper (bitrate, fps cap ≤15, IDR request, NV12 input):

- Extract patterns from `AiVisionFragment` offline video export.
- Used by `CameraAiHttpCompositor` for LAN composited stream.
- Future: offline export calls same helper to avoid two encoder configurations.

### 5. `EncodedVideoSinkMultiplexer` on `EasyPlayerClient` (Phase C — performance milestone)

**Responsibility:** Allow **multiple** `EncodedVideoSink` listeners on one `EasyPlayerClient` instance (or internal fan-out list):

- AI Vision preview client registers sink when LAN `/ai` pass-through subscribers exist **and** pass-through mode is active.
- `ProductionInferenceStreamClient` registers when feasible without breaking I420 inference callback (if incompatible, keep duplicate RTSP + log).

**Consumers:** `CameraAiHttpPublisher` pass-through subscribes to multiplexer instead of opening dedicated PR1 when a session already exists.

**Explicit non-goal:** Multiplexing PR0 live with recording (separate milestone; live already logs `duplicate_rtsp=recording_active`).

## Implementation phases (apply order)

Work in `tasks.md` is grouped to match these phases. **Do not skip Phase A** before shipping pass-through `/ai`; Phase C may trail v1 if timeboxed but must remain in plan.

| Phase | Goal | Delivers | AI Vision touch |
|-------|------|----------|-------------------|
| **A — Foundations** | DRY LAN pass-through; single overlay model | `CameraHttpStreamPublisherCore`, refactor `CameraLiveHttpPublisher`, `CameraAiOverlayState`, Fragment uses overlay state | Fragment refactor only; no HTTP yet |
| **B — `/ai` pass-through + route** | LAN PR1 mirror of live | `CameraAiHttpPublisher` pass-through, `GET /v1/camera/ai`, tests/docs | Overlay state wired; no compositor |
| **C — Composited stream** | AI-on HTTP matches preview | `CameraAiHttpCompositor`, `CompositorFrameProvider`, hot switch, `LiveH264Encoder` | Fragment registers provider; overlay draw shared |
| **D — PR1 encoded sharing** | Fewer RTSP sessions | `EncodedVideoSinkMultiplexer`, hooks in AI Vision player + production client | Optional sink on existing PR1 clients |
| **E — Hardening** | Field-ready | Field checklist, duplicate_rtsp metrics, visual diff notes | — |

### Phase boundaries and acceptance

- **A done:** `/v1/camera/live` regression tests pass; overlay parsing has unit tests independent of Fragment layout.
- **B done:** `ffplay` PR1 pass-through on `/v1/camera/ai` with AI off; no compositor CPU.
- **C done:** AI Vision preview on + HTTP client sees `X-Camera-Ai-Mode: composited` and boxes; hot switch on same connection.
- **D done:** With AI Vision preview + `/ai` pass-through concurrent, logs show **no** `duplicate_rtsp=ai_vision_preview` (or documented exception with shared tap).

### Anti-patterns (explicit)

- Merging `/live` and `/ai` into one URL or query-driven profile switch.
- HTTP inference via high-rate `TextureView.getBitmap`.
- `AiVisionFragment` holding a hard reference to `CameraAiHttpPublisher`.
- Running compositor encoder when `subscriberCount == 0` or AI overlay production inactive.

## Risks / Trade-offs

- **[Risk] Two PR1 RTSP sessions** (HTTP + AI Vision / production) → Mitigation: log duplicates; shared-tap milestone.
- **[Risk] Mid-stream mode switch breaks naive players** → Mitigation: document `X-Camera-Ai-Mode`; keyframe at switch; TS clients may need reconnect (acceptable).
- **[Risk] Compositor CPU when AI on** → Mitigation: encode only with subscribers; cap fps/bitrate; stop encoder when AI off.
- **[Risk] Overlay not pixel-identical to on-device TextureView** → Mitigation: v1 functional parity for boxes/labels; visual diff tests on device.
- **[Risk] Production path has sparse overlay updates (2 s inference)** → Mitigation: hold last overlay between inference ticks; stream stays PR1-like between updates.

## Migration Plan

1. Ship in app release; no cloud migration.
2. Update `docs/network-api-reference.md` with `/v1/camera/ai`, mode header, ffplay examples, coexistence with `/v1/camera/live`.
3. Rollback: remove route, publisher, compositor registration.

## Open Questions

- Can **libai** expose pre-composited Annex-B access units to eliminate App-side `LiveH264Encoder`? (Would simplify Phase C.)
- Whether `ProductionInferenceStreamClient` can attach `EncodedVideoSinkMultiplexer` without disabling I420 inference callbacks (determines Phase D scope).
- Whether production weld HTTP viewers should stay on **pass-through PR1** until preview-style overlay exists (product call; affects when Phase C compositor activates for production-only laser-on).
