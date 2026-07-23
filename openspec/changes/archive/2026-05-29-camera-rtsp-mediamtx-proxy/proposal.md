## Why

`GET /v1/camera/live` bridges the industrial camera RTSP main stream (`/PR0`) to HTTP clients via an in-app publisher (`EasyPlayerClient` / ffmpeg experiments). Field behavior shows unstable ingest, wedged reconnects, and duplicated RTSP sessions when recording is active. LAN tools need a **mature RTSP relay** that fans out multiple viewers from **one** upstream pull without maintaining a custom HTTP byte pump.

[MediaMTX](https://github.com/bluenviron/mediamtx) is purpose-built for RTSP ingest and multi-reader fan-out. Running it as a **bundled native binary** under APK lifecycle control gives predictable start/stop, OTA-upgradable delivery (same pattern as firmware / AI library), and replaces the HTTP live route with a standard **`rtsp://<device-lan-ip>:<port>/<path>`** URL.

## What Changes

- **Remove** **`GET /v1/camera/live`** from `DeviceLocalHttpServer` (**BREAKING**). Clients MUST use the device-hosted RTSP relay instead of chunked HTTP H.264 / MPEG-TS.
- **Bundle** a pinned **MediaMTX** binary per device ABI (minimum `arm64-v8a`) under `app/src/main/assets/mediamtx/`, with a **`make mediamtx`** (or equivalent) build entrypoint to rebuild from source when protocols or version pins change.
- **APK lifecycle**: extract binary + default `mediamtx.yml` to app-private storage, start MediaMTX when the relay is needed (e.g. first subscriber policy or explicit “camera relay enabled” gate), stop when idle per refcount/teardown rules; supervise process exit and restart with bounded backoff.
- **Upstream**: configure MediaMTX to pull **`CameraConfig.RECORDING_RTSP_URL`** (`rtsp://192.168.1.100/PR0`, TCP) once and publish a stable path (e.g. **`/camera/pr0`**) on the device LAN interface.
- **In-app PR0 recording** (Fast / Engineer mode UI, `EasyPlayerClientManger`, `POST /v1/camera/record`): MUST pull from the **MediaMTX fan-out URL** (e.g. `rtsp://127.0.0.1:8554/camera/pr0`), NOT directly from `RECORDING_RTSP_URL`, so the camera sees **at most one** upstream RTSP session for PR0 while relay + record + LAN viewers are active.
- **OTA**: deliver newer MediaMTX builds via existing **`lws-app` OTA** artifact layout (zip payload + semver metadata) and/or newer APK assets; apply upgrade on next process start or coordinated restart without bricking an active relay when avoidable.
- Update **`docs/network-api-reference.md`**, AI inference SSE pairing docs, and integration examples to reference the RTSP URL instead of `/v1/camera/live`.
- **Out of scope (this change)**: replacing `GET /v1/camera/ai`, PR1 inference / `TextureView` preview RTSP paths; HLS/WebRTC egress (RTSP relay only unless explicitly added later). Other PR0 consumers (e.g. `BackgroundLoopRecorder`) SHOULD migrate to the relay in the same change when feasible.

## Capabilities

### New Capabilities

- `mediamtx-binary-bundled-build`: Reproducible cross-compile of MediaMTX for Android ABIs, `make mediamtx` entrypoint, asset placement, and version pin recorded in build metadata.
- `mediamtx-runtime-lifecycle`: APK-owned extract, config generation, process start/stop, upstream pull + LAN publish semantics, observability, and **all in-scope PR0 recording** as relay consumers (single upstream).
- `mediamtx-ota-upgrade`: Semver-gated upgrade of the installed MediaMTX binary from OTA zip and/or bundled APK assets, aligned with existing `lws-app` delivery patterns.

### Modified Capabilities

- `device-local-http-camera-live`: **Remove** HTTP live endpoint requirements; capability superseded by RTSP relay (archive or replace spec at apply time).
- `device-local-http-api`: Remove `GET /v1/camera/live` from the LAN HTTP surface enumeration and cross-route references.
- `device-local-http-ai-inference-sse`: Update pairing guidance — video from device RTSP relay, not `/v1/camera/live`.
- `device-local-http-camera-record`: HTTP record start/stop uses relay ingest URL; coexistence with LAN RTSP viewers via shared MediaMTX path.
- `production-ai-inference-stream-lifecycle`: Main-stream recording in Quick/Engineer mode uses relay URL; observability reflects relay, not direct camera RTSP.
- `lws-app-ota-semver`: Document MediaMTX as an optional OTA-delivered native artifact with version comparison rules.

## Impact

- **Code**: remove `CameraLiveHttpPublisher` / ffmpeg live bridge; add MediaMTX coordinator; switch `EasyPlayerClientManger` / `CameraRecordCoordinator` / `CameraController` record paths to relay URL; ensure relay is running before record start; OTA unpack hook.
- **API**: **BREAKING** — `/v1/camera/live` and `?format=ts` no longer exist; clients use `rtsp://<device-lan-ip>:8554/camera/pr0` (port/path per design).
- **Build**: `Makefile` / `scripts/ci/build-mediamtx.sh`, `.gitignore` for copied assets, CI artifact caching.
- **Docs**: `docs/network-api-reference.md`, `docs/camera-http-ai-vision-integration.md`, ffplay/VLC/Flutter examples.
- **Tests**: JVM route tests drop live HTTP expectations; instrumented tests probe RTSP relay when camera network available.
- **Relation to in-flight work**: supersedes `openspec/changes/camera-live-http-ffmpeg-h264` (ffmpeg HTTP bridge); that change should not be applied if this lands.
