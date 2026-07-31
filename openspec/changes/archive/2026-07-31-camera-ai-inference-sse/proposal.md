## Why

P3.3 landed App-owned `lws_ai_daemon` smoke (`daemon_ready` / `ping`), but LAN `GET /v1/camera/ai` still always returns plain `503 camera_ai_unavailable`. Mobile/LAN clients already expect lws-ui’s SSE contract (`idle` / `start` / `running` / `stop` / `error`) paired with RTSP `pr0`. Without this route, cloud/local HTTP parity and production AI overlay tooling cannot attach.

## What Changes

- Implement lws-ui-aligned **`GET /v1/camera/ai`** as Server-Sent Events on `:5580` (not video bytes, not `ApiResult` on success).
- Add Dart **`AiInferenceSseHub`** + **`CameraAiHttpPublisher`** that fan-out lifecycle/sample events to concurrent subscribers.
- Bridge **`lws_ai_daemon` evt.sock** StreamDetect uplink (`session_start` / `detect_result` / `session_stop` / `pipeline_state`) into the publisher (lens_det → `running`).
- Extend App AI supervisor with StreamDetect cmd helpers (`configure_session`, `stream_detect_start`/`stop`, `laser_state`, `ai_assist_config`) and a minimal **weld holder** that starts PR1 detect when laser is ON.
- When the AI daemon is not ready, keep **plain-text 503** (`camera_ai_unavailable`); do not hang.
- **Out of scope:** `GET /v1/videos/:id/ai`, AI Vision UI dual-holder, composited H.264, rootfs AI unit.

## Capabilities

### New Capabilities

- `device-local-http-ai-inference-sse`: Shared AI SSE media type, event names, payloads, idle cadence, and camera-route clock semantics for `GET /v1/camera/ai`.
- `camera-ai-stream-detect-bridge`: Daemon evt → publisher mapping and weld-driven StreamDetect lifecycle on MediaMTX `camera/pr1`.

### Modified Capabilities

- `device-local-http-api`: Tighten `GET /v1/camera/ai` from “SSE when available else 503” to the concrete SSE contract (headers, first `idle`, no video bytes).
- `ai-daemon-unix-socket-ipc`: Require App to consume StreamDetect evt types and issue StreamDetect/laser/assist cmds needed for live camera AI (beyond ping smoke).

## Impact

- App: `lib/features/ai/` (hub, publisher, mapper, coordinator), `device_local_http_server.dart`, `cloud_local_runtime.dart`, shared `AiDaemonSupervisor` lifecycle.
- Tests: SSE framing / timeline unit tests; update `device_local_http_parity_test` for available + unavailable paths.
- Docs: network/API notes only if already mirrored in-repo; primary contract lives in OpenSpec.
- Depends on existing `app-owned-ai-daemon` packaging (`/opt/hmi/bin/lws_ai_daemon`, `/run/hmi/ai/*.sock`).
