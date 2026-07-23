## 1. Envelope helpers and parsing

- [x] 1.1 Add a small envelope model or parser (v, type, id, ts, payload) with validation for required top-level fields and object-typed `payload`
- [x] 1.2 Add unit tests for valid/invalid envelopes (missing field, wrong `payload` type, unsupported `v`)

## 2. DeviceWebSocketConnectionManager refactor

- [x] 2.1 Refactor inbound handling to parse the envelope first, then branch on `type`; validate `connected` payload (`sn`, `connection_id`) before transitioning to online
- [x] 2.2 Refactor `sendHeartbeat` to emit envelope with `v=1`, generated `id`, millisecond `ts`, `type=heartbeat`, `payload={}`
- [x] 2.3 Refactor `sendCommandAck` (and any other outbound JSON) to use the unified envelope with `type=ack` and business fields nested under `payload` per server contract
- [x] 2.4 Update `heartbeat_ack` telemetry to correlate using envelope `id` (and/or agreed payload) instead of legacy top-level `correlationId`
- [x] 2.5 Update or extend `command` inbound handling to read from `payload` if server adopts envelope for commands (coordinate with backend)

## 3. Integration and documentation

- [x] 3.1 Update `DeviceWebSocketConnectionTest` (or add tests) for envelope serialization and connected-payload validation
- [x] 3.2 Align `docs/device-websocket-migration.md` (or linked API doc) with the envelope and snake_case `payload` keys for `connected`
- [x] 3.3 Coordinate backend rollout (envelope for `connected`, `heartbeat_ack`, acceptance of envelope `heartbeat`); remove temporary legacy parsing if used — **client ships envelope-only; no flat-frame fallback in app**
