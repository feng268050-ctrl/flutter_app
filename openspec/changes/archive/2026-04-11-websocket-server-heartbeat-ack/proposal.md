## Why

The server may initiate keepalive using the unified WebSocket envelope with a `heartbeat` frame. Without a client reply, the session can be treated as stale or closed by policy. The app already documents device-originated heartbeats and server `heartbeat_ack`; the reverse direction (server `heartbeat` → client `heartbeat_ack`) is missing from the contract and implementation, so the client cannot satisfy the server contract.

## What Changes

- Treat inbound unified-envelope frames with `type` `heartbeat` from the server as a keepalive that **must** be answered.
- Send an outbound unified-envelope frame with `type` `heartbeat_ack`, fresh device-generated `id`, current millisecond `ts`, `v` equal to `1`, and **`payload` exactly `{}`** (empty object).
- Extend the existing WebSocket specs so this exchange is normative alongside the existing device-initiated heartbeat flow.

## Capabilities

### New Capabilities

- _(none — behavior extends the existing device WebSocket envelope and connectivity specs.)_

### Modified Capabilities

- `device-ws-unified-envelope`: Add requirements for **server-originated** `heartbeat` inbound frames and **device-originated** `heartbeat_ack` replies, including empty `{}` `payload` on the ack.
- `device-websocket-connectivity`: Add a requirement or scenario that the transport handles server-initiated `heartbeat` and emits the corresponding `heartbeat_ack` using the unified envelope.

## Impact

- Device WebSocket message handling / transport (where inbound `type` is dispatched).
- Tests or contract checks for the new message pair, if present for other WS types.
- No change to MQTT or unrelated channels unless they share the same handler abstraction.
