## Context

- `app-owned-ai-daemon` ships `lws_ai_daemon` under `/opt/hmi` and smoke-connects `/run/hmi/ai/{cmd,evt}.sock`.
- `DeviceLocalHttpServer` already routes `GET /v1/camera/ai` but always returns 503; monitor SSE hubs show the Dart fan-out pattern to reuse.
- lws-ui contract: SSE JSON only (`idle`/`start`/`running`/`stop`/`error`); video stays on MediaMTX `rtsp://…:8554/camera/pr0`. Detect samples come from daemon StreamDetect uplink on evt.sock (same JSON as former JNI).

## Goals / Non-Goals

**Goals:**
- LAN clients get a stable SSE stream matching lws-ui field/event names for live camera AI.
- One infer pipeline fans out to N HTTP subscribers.
- Weld path: laser ON → configure + `stream_detect_start` on local PR1 → evt → SSE; laser OFF → stop / `laser_off`.

**Non-Goals:**
- Process-video `/v1/videos/:id/ai` and media-timeline clock.
- AI Vision preview holder / on-device overlay UI.
- Changing native detect algorithms or RKNN models.

## Decisions

1. **Mirror lws-ui layering in Dart**  
   `AiInferenceSseHub` (framing + idle timer + connection-relative clock) ← `CameraAiHttpPublisher` (session + lens_det mapping) ← daemon evt ingest.  
   **Why:** Keeps wire parity with existing mobile clients; matches monitor SSE structure already in-tree.

2. **Shared `AiDaemonSupervisor` singleton**  
   Replace throwaway `AiDaemonSupervisor()` in `main.dart` with an App-owned instance that keeps cmd/evt sockets open and exposes StreamDetect cmds.  
   **Why:** SSE and weld coordinator need the same socket client; reconnect on cyber_pm restart.

3. **Availability gate = daemon ready**  
   `cameraAiAvailable` returns true when supervisor `isStarted` (ping succeeded). Camera eth / MediaMTX failure surfaces as idle-only or later `error`/`stop`, not connection refuse—unless daemon missing → 503.  
   **Alt considered:** Require MediaMTX before acquire → rejected; lws-ui gates on camera LAN ready, but Linux MediaMTX is App-owned and may start after HTTP; idle SSE is still useful.

4. **Weld holder only in this slice**  
   `NativeStreamDetectCoordinator`-style holder set with `weld` only; AI Vision / manual ZP deferred. RTSP URL = `rtsp://127.0.0.1:8554/camera/pr1`.  
   **Why:** Production laser path is the primary LAN consumer; dual-holder complexity can land with AI Vision UI.

5. **`running` boxes from `target.json` when present**  
   Parse lens_det `summaryJson` → `files[]` → read `target.json` under workdir (absolute or relative). On parse failure, still emit `running` with empty `boxes` and ERROR status.  
   **Why:** Matches lws-ui wire; avoids inventing a second overlay format.

6. **Connection-relative `timestampMs`**  
   Anchor at SSE acquire; ignore native sample epoch for the wire field (native time remains only for mapping/debug).  
   **Why:** Exact lws-ui camera-route clock.

## Risks / Trade-offs

- [Daemon restarts mid-SSE] → cyber_pm restarts binary; App reconnects sockets and may emit `error`/`stop`; clients reconnect SSE.
- [PR1 not yet published when laser ON] → start may fail; retry briefly or wait for MediaMTX ready signal; do not block HTTP accept loop.
- [target.json path relative to daemon cwd] → search workdir roots when resolving `files[]`.
- [No laser Modbus yet on some boards] → SSE still serves `idle`; no `start` until pipeline runs (acceptable).

## Migration Plan

1. Ship App with SSE implementation (`make build-app` / `push-app`).
2. Board must already have AI prebuilt (`make build-ai`).
3. Rollback: clients that only handled 503 keep working if daemon binary missing; no GPT/rootfs change.

## Open Questions

- None blocking: AI Vision holder and `/v1/videos/:id/ai` explicitly deferred.
