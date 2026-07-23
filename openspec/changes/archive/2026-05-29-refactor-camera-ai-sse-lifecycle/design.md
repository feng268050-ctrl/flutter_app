## Context

Both AI SSE routes use dedicated `AiInferenceSseHub` instances:

| Route | Publisher | Data source |
|-------|-----------|-------------|
| `GET /v1/camera/ai` | `CameraAiHttpPublisher` | Production PR1 (`ProductionInferenceStreamClient`, laser ON/OFF) and/or AI Vision live preview (`AiVisionFragment`) |
| `GET /v1/videos/:id/ai` | `ProcessVideoAiSession` | Decoded frames from one process-video file via internal 1× playback clock |

Today both hubs emit only `heartbeat` (every 15 s) and `inference` (each completed `LensGuardInferenceResult`). No `start`/`stop`; clients joining mid-session wait for the first sample.

## Goals / Non-Goals

**Goals:**

- **One SSE lifecycle contract** for both routes: `idle`, `start`, `running`, `stop`, `error`.
- Push **`idle` immediately** on every new subscriber.
- Same JSON field shapes for all lifecycle events on both routes.
- Document the **two** allowed differences: data source and `timestampMs` clock origin.
- Wire `start`/`stop` from production infer, AI Vision live, and `ProcessVideoAiSession` lifecycles.

**Non-Goals:**

- Changing RTSP relay URLs or `/stream` video routes.
- Cloud Worker / WebSocket APIs.
- Backward-compatible dual emission of `heartbeat` / `inference`.
- Renaming the OpenSpec change directory (historical name; scope now covers both routes).

## Decisions

### 1. Single hub lifecycle mode (no legacy profile)

**Decision:** `AiInferenceSseHub` always uses lifecycle events (`idle`/`start`/`running`/`stop`). Remove the planned `SseEventProfile` split — both camera and process-video hub instances behave identically.

**Rationale:** User requirement: contracts are the same except data source and `timestampMs` clock.

### 2. Shared event contract (both routes)

| Event | Purpose | `data` JSON |
|-------|---------|-------------|
| **`idle`** | Keepalive + state snapshot | `{"timestampMs":<n>,"inferenceActive":<bool>}` |
| **`start`** | Inference session began | See §3 |
| **`running`** | One completed sample (was `inference`) | Unified result fields + `sessionId` |
| **`stop`** | Inference session ended | See §4 |
| **`error`** | Fatal (unchanged) | `{"code":<int>,"message":"<str>"}` |

- **`idle` interval**: Every **15 s** while connected (replaces `heartbeat`).
- **Immediate `idle`**: On `acquireSubscriber()`, enqueue `idle` with `timestampMs` per clock strategy (§5) and `inferenceActive` from session state.

### 3. `start` payload (shared shape)

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "timestampMs": 0,
  "source": "production_weld",
  "samplingIntervalMs": 2000,
  "imageWidth": 1920,
  "imageHeight": 1080
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `sessionId` | string (UUID) | yes | New UUID per infer epoch |
| `timestampMs` | number | yes | Per-route clock at session start (§5) |
| `source` | string | yes | Session source tag (§6) |
| `samplingIntervalMs` | number | yes | `2000` production, `500` AI Vision live / process video |
| `imageWidth` | number | no | Frame width when known |
| `imageHeight` | number | no | Frame height when known |

**Mid-connection join:** If a session is already active, emit `start` immediately after the first `idle` (same `sessionId` as the ongoing epoch).

### 4. `stop` payload (shared shape)

```json
{
  "sessionId": "550e8400-e29b-41d4-a716-446655440000",
  "timestampMs": 45230,
  "reason": "laser_off"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `sessionId` | string | yes | Matches preceding `start` |
| `timestampMs` | number | yes | Per-route clock at session end (§5) |
| `reason` | string | yes | See table below |

| `reason` | Route | When |
|----------|-------|------|
| `laser_off` | camera | Production infer stopped (laser OFF) |
| `preview_stopped` | camera | AI Vision live preview infer deactivated |
| `session_complete` | video | `ProcessVideoAiSession` reached end-of-file |
| `session_cancelled` | video | User or UI cancelled detect session |
| `force_restart` | video | `?force=1` or explicit session restart |
| `stream_error` | both | Unrecoverable decode/infer/RTSP failure |
| `release` | both | App shutdown or publisher release |

After `stop`, periodic `idle` MUST set `inferenceActive: false`.

### 5. `timestampMs` clock strategies (the only structural difference)

**Decision:** Inject a `TimestampClock` (or equivalent) into each hub instance:

| Route | Clock | `timestampMs` meaning |
|-------|-------|----------------------|
| **`GET /v1/camera/ai`** | `ConnectionRelativeClock` | Milliseconds since **this SSE connection** was established (`LiveSseTimeline`, existing behavior) |
| **`GET /v1/videos/:id/ai`** | `MediaTimelineClock` | Milliseconds on **source recording timeline** from 0, equal to the session playback position when the event fires (aligned with `GET /v1/videos/:id/stream`) |

- First `idle` on connect: `timestampMs` = `0` on both routes (connection t=0 for camera; media t=0 for video).
- Periodic `idle` during an active video session: `timestampMs` = current session playback position.
- Periodic `idle` during active camera infer: `timestampMs` = connection elapsed ms; `inferenceActive: true`.
- `running.timestampMs` follows the same clock as other events on that route.

**Note:** Drop the separate `streamTimeMs` field from the unified contract — `timestampMs` alone carries timeline position on the video route (simpler, one field name both routes).

### 6. Session `source` values

| `start.source` | Route |
|----------------|-------|
| `production_weld` | camera — Quick/Engineer laser ON |
| `ai_vision_live` | camera — AI Vision live tab |
| `process_video` | video — `ProcessVideoAiSession` |

`running.data.source` remains the infer-path tag from `LensGuardInferenceResult` (e.g. `live_infer`, `process_video`) — unchanged from today.

### 7. Session coordinators

**Camera (`CameraAiSseSessionState` on `CameraAiHttpPublisher`):**

- Tracks `sessionId`, `source`, session start connection time.
- `ProductionInferenceStreamClient.start/stop` → hooks.
- `AiVisionFragment` live infer enable/disable → hooks.
- Production wins if both production and AI Vision would be active.

**Video (`ProcessVideoAiSession`):**

- Emit `start` when session begins processing (after successful create, before first sample).
- Emit `stop` on EOS (`session_complete`), cancel, `force_restart`, or error.
- `inferenceActive` for `idle` reflects whether session decode/infer loop is running.

Both coordinators broadcast `start`/`stop`/`running` only when subscribers exist, except per-subscriber connect `idle` (and mid-join `start` replay).

### 8. `running` payload

Reuse `AiInferenceSseJson` unified builder; event name `running`; include `sessionId` when session active. Same fields as prior `inference` JSON (`timestampMs`, `success`, `code`, `level`, `status`, `message`, `imageWidth`, `imageHeight`, `boxes`, `source`).

### 9. JSON helpers

`AiInferenceSseJson`: `idleData`, `startData`, `stopData`, `runningData` (or extend `inferenceData`).

### 10. Tests & docs

- Camera timeline tests (`ConnectionRelativeClock`).
- Process-video tests (`MediaTimelineClock`, `start` at 0, `running` at sample positions, `stop` at duration).
- Update `docs/network-api-reference.md` for **both** SSE sections.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| **BREAKING** for LAN clients on both routes | Document; no dual emit |
| Removing `streamTimeMs` on video route | `timestampMs` now carries media position; update docs and any tests |
| Mid-connection join misses earlier `running` events | Expected SSE semantics; hold-forward from first `running` |
| Two hub instances must stay in sync behaviorally | Shared hub code + clock injection; no profile fork |

## Migration Plan

1. Implement unified hub lifecycle + clock injection + JSON helpers.
2. Wire camera and process-video session coordinators.
3. Update tests and `network-api-reference.md` (both routes).
4. Ship in next app release.
5. **Rollback:** Revert event names and remove session coordinators.

## Open Questions

_(none)_
