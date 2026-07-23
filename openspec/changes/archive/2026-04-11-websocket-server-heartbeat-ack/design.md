## Context

The Android app uses `DeviceWebSocketConnectionManager` (OkHttp `WebSocket`) with `DeviceWebSocketEnvelope` for unified JSON frames (`v`, `type`, `id`, `ts`, `payload`). Inbound handling in `onInboundMessage` already treats `connected`, `heartbeat_ack`, `ack`, `command.send_process_param`, and `command`. Outbound heartbeats use `sendHeartbeat` → `type` `heartbeat` and empty `payload`. There is **no** branch for inbound server `heartbeat`, so the client never emits a device-originated `heartbeat_ack` in response to the server.

## Goals / Non-Goals

**Goals:**

- On a valid inbound unified-envelope frame with `type` `heartbeat` from the server, send an outbound `heartbeat_ack` frame with `payload` equal to `{}`, using a new device-generated `id`, current millisecond `ts`, and `v` equal to `1`, consistent with `device-ws-unified-envelope`.
- Keep behavior aligned with existing outbound path constraints (same serialization helper as other frames).

**Non-Goals:**

- Changing server-initiated keepalive frequency or adding client timers for server heartbeats.
- Responding when the session is not yet `ONLINE` (same practical constraint as `sendRawJson` today, which requires `isOnlineReady()`); if the server ever sends `heartbeat` before `connected`, that remains undefined unless product asks to relax the send gate.

## Decisions

1. **Handle server `heartbeat` in `DeviceWebSocketConnectionManager.onInboundMessage`**  
   Centralizes protocol handling next to `heartbeat_ack` ingestion and reuses `DeviceWebSocketEnvelope.toJson("heartbeat_ack", Map.of(), id, ts)` (or equivalent empty map) so the wire shape matches existing tests and docs.

2. **Validate minimal envelope rules before replying**  
   Reuse existing `parse` and `v == 1` checks. Optionally verify `payload` is an empty object for symmetry with the spec; invalid frames should follow the same policy as other drops (log and ignore) to avoid acking malformed traffic.

3. **Telemetry**  
   Mirror the inbound `heartbeat_ack` path with a `DeviceChannelTelemetry.logDataPath` event (e.g. `server_heartbeat_replied` or reuse a neutral `keepalive` outcome) so observability stays consistent with device-initiated keepalive logging.

**Alternatives considered:** A separate `HeartbeatController` class — rejected as unnecessary for a single branch and two lines of send logic; a new capability spec only — rejected because the contract spans envelope shape and transport behavior.

## Risks / Trade-offs

- **[Risk] Sending `heartbeat_ack` while not online fails silently** (`sendRawJson` returns false) → **Mitigation:** Document under non-goals; if needed later, allow send in `CONNECTED_PENDING` with explicit product sign-off.
- **[Risk] Duplicate or spoofed `heartbeat` frames** → **Mitigation:** Stateless reply per frame; no session mutation beyond logging.

## Migration Plan

Deploy with the app release; no data migration. Rollback is reverting the handler branch.

## Open Questions

- None for the stated contract (`heartbeat` in → `heartbeat_ack` with `{}` out).
