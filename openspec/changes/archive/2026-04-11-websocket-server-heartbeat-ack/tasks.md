## 1. Inbound server heartbeat handling

- [x] 1.1 In `DeviceWebSocketConnectionManager.onInboundMessage`, after envelope validation, add a branch for inbound `heartbeat` that sends `heartbeat_ack` using `DeviceWebSocketEnvelope.toJson` with empty `Map`/`Map.of()` payload, new `id`, and current millisecond `ts`
- [x] 1.2 Gate the reply with the same outbound rules as other frames (e.g. `sendRawJson` / online-ready); if a helper is needed for clarity (e.g. `sendHeartbeatAck`), keep it private to the manager

## 2. Observability and docs

- [x] 2.1 Emit `DeviceChannelTelemetry.logDataPath` for the server→client heartbeat handling path (consistent severity fields with existing `heartbeat_ack` keepalive logging)
- [x] 2.2 Update `docs/device-websocket-migration.md` (or the canonical WS contract doc linked from it) to document bidirectional heartbeat: server `heartbeat` → device `heartbeat_ack` with `{}` payload

## 3. Verification

- [x] 3.1 Extend `DeviceWebSocketConnectionTest` (or add focused tests) to assert JSON shape for outbound `heartbeat_ack` and parsing of inbound server `heartbeat`
- [x] 3.2 Run the relevant unit test task / Gradle test target for the `network.ws` package
