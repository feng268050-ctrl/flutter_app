## Context

The HMI app already:

- Pulls **PR0** (`rtsp://192.168.1.100/PR0`) via `EasyPlayerClientManger` for **recording** (virtual `Surface`, `EasyMuxer2` writes encoded H.264/H.265).
- Pulls **PR1** via `ProductionInferenceStreamClient` for weld-time AI (independent lifecycle).
- Serves **LAN HTTP** on **`0.0.0.0:8080`** via `DeviceLocalHttpServer` (`GET /v1/videos/.../stream` serves **local MP4 files**, not camera live).

`EasyPlayerClient` already receives **encoded video access units** (`Client.FrameInfo` with H.264/H.265) on the path used for muxing (`muxer2.writeFrame`), before or alongside MediaCodec display decode. Multiple `EasyPlayerClient` instances on the same PR0 URL would duplicate RTSP sessions and likely duplicate decode work.

Stakeholders: mobile/support tools on device Wi‑Fi, factory LAN testers, future browser dashboards. Constraint: RK3588-class tablet CPU; 1080p main stream must not add a second full decode pipeline per viewer.

## Goals / Non-Goals

**Goals:**

- Expose **`GET /v1/camera/live`** on the existing embedded server (port **8080**).
- Source **PR0 only** (`CameraConfig.RECORDING_RTSP_URL`, TCP transport like `Client.TRANSTYPE_TCP`).
- **Single shared ingest** while any HTTP live client is connected (reference counting).
- **Prefer encoded-bitstream relay** (demux → HTTP chunked body) so HTTP viewers do not force YUV decode.
- **Default H.264 pass-through** for broad player compatibility (Flutter, VLC, ffplay).
- **Optional MPEG-TS** via `?format=ts` when a client needs `video/mp2t`.
- Clear HTTP errors when camera/eth0 is down or RTSP fails (503 + short plain text; not hang forever).
- Document usage in `docs/network-api-reference.md` (Content-Type, `format` query, VLC/Flutter notes, coexistence with recording).

**Non-Goals:**

- Sub-stream `/PR1`, AI Vision TextureView path, or WebSocket video push.
- TLS, local HTTP auth, or cloud Worker proxy.
- Transrating (1080p→720p) or on-device re-encode unless pass-through proves infeasible on target hardware (then document fallback).
- Replacing in-app RTSP preview (`AiVisionFragment`); this API is for **external** HTTP clients only.
- Browser `<video>` without a codec-aware player (raw H.264/TS is not HTML5-native).

## Decisions

1. **Route and response shape**

   **Decision:** `GET /v1/camera/live` returns **HTTP 200** with chunked body and **`Cache-Control: no-cache`**.

   - **Default (no query / `?format=h264`):** **`Content-Type: video/H264`**, body = **Annex-B H.264** access units from RTSP demux, written directly to HTTP subscribers (no TS mux).
   - **Optional `?format=ts`:** **`Content-Type: video/mp2t`**, body = **MPEG-TS** remux via `MpegTsMuxer` (PAT/PMT emitted on subscribe).
   - **`X-Camera-Live-Format`** response header: `h264` or `ts`.

   **Rationale:** Field testing showed many players (VLC, ffplay, Flutter ffmpeg paths) play raw H.264 over HTTP more reliably than early TS-only mux; TS remains available for clients that require transport stream. Browsers opening the URL in the address bar may download rather than play — expected for non-HTML5 formats.

   **Alternatives:** TS-only default (rejected after playback issues); **302 redirect to RTSP** (browsers cannot play RTSP); **fMP4** (follow-up if MSE clients need it).

2. **Publisher component — `CameraLiveHttpPublisher`**

   **Decision:** Singleton owning:

   - `acquire(context, LiveFormat)` / `release()` refcounts from each active HTTP response.
   - One **`EasyPlayerClient`** on virtual `Surface` when refcount transitions 0→1; stop when 1→0.
   - **`EncodedVideoSink`** + **`setEncodedPassThroughOnly(true)`** so HTTP live does not decode to display.
   - Format switch while active subscribers exist: tear down and restart publisher when `LiveFormat` changes.

   **Rationale:** Centralizes lifecycle; HTTP handler only subscribes/unsubscribes per connection.

3. **Avoid redundant decode**

   **Decision (ordered):**

   1. **Pass-through path:** `EncodedVideoSink` receives `FrameInfo` → fan-out to subscribers (raw H.264 or `MpegTsMuxer` for TS). **No** `MediaCodec` display decode for HTTP live.
   2. **Coexistence with recording:** When `EasyPlayerClientManger` is actively recording on PR0, v1 uses a **separate** RTSP session for HTTP live and logs `duplicate_rtsp=recording_active`. Shared tap is a follow-up.
   3. **Never** start a separate RTSP session per HTTP viewer — fan-out in process only (max 4 subscribers).

4. **HTTP handler integration**

   **Decision:** `DeviceLocalHttpServer` dispatches `GET /v1/camera/live`:

   - Parses `format` query via `LiveFormat.fromQuery` (default **H264**).
   - Returns **503** `text/plain` if `appContext` null, `setCameraNetworkSegment()` fails, publisher `acquire` returns null (timeout, subscriber limit).
   - Chunked response; on disconnect, `release()` subscriber.
   - **`Connection: close`** for live streams.

5. **Threading**

   **Decision:** RTSP read on `EasyPlayerClient` worker; per-subscriber queue with backpressure (bounded queue; drop oldest on slow client).

6. **Camera URL and transport**

   **Decision:** Fixed `CameraConfig.RECORDING_RTSP_URL`; transport **TCP**; only **`format`** query in v1 (`h264` | `ts`).

## Risks / Trade-offs

- **[Risk] Two RTSP sessions when recording + live HTTP** → Mitigation: log `duplicate_rtsp=recording_active`; shared tap milestone.
- **[Risk] H.265 on PR0** → Mitigation: log codec; document VLC; H.264 assumed for v1 field devices.
- **[Risk] Mixed formats with concurrent viewers** → Mitigation: publisher restarts on format switch; avoid mixing `ts` and `h264` viewers simultaneously.
- **[Risk] NanoHTTPD concurrent live viewers** → Mitigation: cap 4 subscribers, 503 when exceeded.
- **[Risk] Cleartext 1080p on LAN** → Accepted (same as `/v1/videos/:id/stream`).

## Migration Plan

1. Ship in app release; no server/cloud migration.
2. Update `docs/network-api-reference.md` with default H.264 URL, optional `?format=ts`, ffplay/VLC/Flutter examples.
3. Rollback: remove route and publisher; no DB migration.

## Open Questions

- Shared encoded tap with `EasyPlayerClientManger` during weld + remote view (recommended before heavy concurrent use).
- Whether mobile team needs **fMP4** for in-browser MSE (out of v1 scope).
