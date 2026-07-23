## Why

Device WebSocket frames today mix top-level fields (`type`, `timestamp`, `commandId`, etc.), which makes versioning, correlation, and server/client symmetry harder as more message types appear. A single bidirectional envelope keeps parsing and evolution predictable and aligns the app with a clear contract for `v`, `type`, `id`, `ts`, and nested `payload`.

## What Changes

- **BREAKING**: All JSON text frames on the device WebSocket SHALL use a unified envelope: `v`, `type`, `id`, `ts`, `payload` (semantics defined in the new spec). Flat legacy frames (e.g. top-level `type` with business fields alongside) are no longer the contract for new work; rollout MAY require server and app to cut over together or a short compatibility window (see design).
- Define normative payloads for the initial types:
  - Device → server: `heartbeat` with `payload` as empty object `{}`.
  - Server → device: `heartbeat_ack` with `payload` as `{}`.
  - Server → device: `connected` with `payload` containing `sn` and `connection_id`.
- Update connectivity and heartbeat requirements in the existing WebSocket spec so “online” and keepalive behavior are expressed in terms of the envelope (not ad hoc top-level fields).

## Capabilities

### New Capabilities

- `device-ws-unified-envelope`: Normative envelope schema, field rules, and payload contracts for `heartbeat`, `heartbeat_ack`, and `connected`.

### Modified Capabilities

- `device-websocket-connectivity`: Requirements that today describe `connected` and heartbeat/ACK as flat JSON SHALL be updated to the envelope model while preserving lifecycle semantics (online gating, reconnect backoff reset, keepalive handling).

## Impact

- **App**: `DeviceWebSocketConnectionManager` (and any callers building or parsing WS JSON) must serialize and deserialize the envelope; telemetry that reads `correlationId` from `heartbeat_ack` must use envelope-level `id` or an agreed payload field.
- **Backend / Durable Objects**: Outbound `connected`, `heartbeat_ack`, and inbound `heartbeat` must match the envelope; any intermediate proxies or docs (`docs/device-websocket-migration.md`) should be updated in implementation follow-up.
- **Tests**: Unit tests for URL/backoff remain; add or adjust tests for frame parsing and emission.
