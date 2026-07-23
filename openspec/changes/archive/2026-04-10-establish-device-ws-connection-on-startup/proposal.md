## Why

Device-side connectivity is currently MQTT-focused, but the backend now exposes a device WebSocket endpoint that should become the online command/data channel. We need startup and network-recovery connection behavior now so devices can reliably come online in both production and test release channels.

## What Changes

- Add device WebSocket connection bootstrap on app startup and after Wi-Fi/network recovery.
- Select WS host by release channel (`RELEASE_CHANNEL=1` -> production host, otherwise test host).
- Build connection URL as `wss://<host>/ws/device?sn=<device-sn>` and treat server `connected` frame as online-ready.
- Add disconnect handling and exponential backoff reconnect strategy (`1s`, `2s`, `4s`, ... with upper bound).
- Handle auth and session replacement behaviors:
  - treat HTTP `401` upgrade failure as device registration/SN validity issue and surface actionable diagnostics;
  - handle close `4409` as expected connection replacement behavior.
- Support protocol-level heartbeat and command ACK payload handling aligned with server contract.

## Capabilities

### New Capabilities
- `device-websocket-connectivity`: Device WebSocket lifecycle, environment-aware endpoint selection, handshake/online semantics, reconnect policy, and protocol keepalive/ack behavior.

### Modified Capabilities
- `device-command-channel-abstraction`: Extend command-channel requirements to ensure ACK behavior works over the WebSocket-backed transport and respects new connection lifecycle semantics.
- `device-data-channel-abstraction`: Extend data-channel requirements to align online/offline state and heartbeat behavior with WebSocket transport events.

## Impact

- Affected code: app networking stack, channel abstractions, connection lifecycle manager, and telemetry/logging around device online status.
- Affected APIs/protocol: device-to-server transport shifts toward `wss://.../ws/device` contract with `connected`, `heartbeat_ack`, command ACK, and close/error handling semantics.
- Environments: production and test channels route to different WS hosts while preserving reusable constants for future REST API migration.
- Risks: reconnect loops, false-online state before `connected`, and inadequate handling of `401` / `4409` edge cases if lifecycle transitions are not explicit.
