## Why

LAN clients (mobile apps, factory tools, support dashboards) can already call the device’s embedded HTTP API on port **8080** for video files and process data, but they cannot view the **industrial camera’s live feed** without RTSP-aware players and direct access to the camera subnet. Operators need a simple **`GET`** URL on the **device LAN IP** that shows the same high-quality **main stream (`/PR0`)** used for recording, without adding another full decode path on the already busy HMI (AI Vision, PR1 inference, PR0 recording).

## What Changes

- Add **`GET /v1/camera/live`** on `DeviceLocalHttpServer` (`0.0.0.0:8080`).
- On request, bridge to the camera **RTSP main stream** (`CameraConfig.RECORDING_RTSP_URL` → `rtsp://<camera>/PR0`, TCP transport consistent with existing `EasyPlayerClient` usage).
- Response SHALL be a **player-friendly HTTP live format** without re-encode:
  - **Default:** **Annex-B H.264** elementary stream (`Content-Type: video/H264`) — best for VLC, ffplay, Flutter (`media_kit` / `ffmpeg_kit` / `flutter_vlc_player`).
  - **Optional:** **`?format=ts`** → **MPEG-TS** (`Content-Type: video/mp2t`) for clients that prefer transport stream.
- Response header **`X-Camera-Live-Format`** (`h264` | `ts`) identifies the active mux mode.
- Introduce a **reference-counted live publisher** so multiple simultaneous HTTP viewers share **one** RTSP ingest and **zero additional decode** when pass-through is used; avoid opening a second PR0 session while `EasyPlayerClientManger` is already recording on PR0 when sharing is feasible (v1 logs `duplicate_rtsp=recording_active` when both run).
- Document the endpoint in `docs/network-api-reference.md` under device local HTTP.
- Non-goals for this change: cloud Worker exposure, TLS on device, authentication on local HTTP (same LAN trust model as existing `/v1/videos`), sub-stream `/PR1` live, WebSocket streaming.

## Capabilities

### New Capabilities

- `device-local-http-camera-live`: Embedded route `GET /v1/camera/live`, live publisher lifecycle, stream formats (H.264 default, optional TS), error responses, coexistence with PR0 recording / PR1 inference, and performance constraints (single ingest, no redundant decode).

### Modified Capabilities

- `device-local-http-api`: Extend the LAN HTTP surface documentation requirement to include the camera live route alongside existing video routes (no change to `/v1/videos` semantics).

## Impact

- **Code**: `DeviceLocalHttpServer` (new route), `CameraLiveHttpPublisher`, `MpegTsMuxer`, `EncodedVideoSink` on `EasyPlayerClient`; `CameraConfig` for URL constants only (no new runtime config).
- **Dependencies**: Reuse existing EasyDarwin / `EasyPlayerClient` stack; no new cloud APIs.
- **Performance / device**: One shared PR0 RTSP session per active live-viewer epoch (per format); CPU/bandwidth bounded by viewer count × relay cost (not × full 1080p decode).
- **Network**: Clients use `http://<device-wifi-ip>:8080/v1/camera/live`; camera remains on eth0 (`192.168.1.100`); no exposure of camera credentials on the HTTP response.
- **Docs**: `docs/network-api-reference.md`, optional Dev/probe note.
