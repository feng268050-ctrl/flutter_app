## Why

When the device reconnects to the WebSocket, there is a window where the server may still serve **stale cached parameters** because it has not yet received a fresh remote snapshot. If the server asks for stats only after reconnect timing races with client availability, operators see outdated data. Pushing an immediate **online snapshot** as soon as the transport is up lets the backend refresh its database early, so cached reads stay reasonably fresh even during reconnect churn.

A second goal is **end-user visibility**: as soon as the device is on the wire, the user’s mobile app (and any other consumers fed from the same backend state) should be able to load or receive **up-to-date live device data**, instead of waiting for a later poll or a race-prone stat request during reconnect. Persisting the connect-time snapshot gives the server a fresh row to fan out or serve to apps immediately after the device session exists at the transport layer.

## What Changes

- **Remove the `connected` application message from the contract** (see capability deltas): the device **SHALL NOT** depend on an inbound `connected` frame for session readiness, online state, or sending `device.online`.
- After the device WebSocket **transport successfully opens** (new session or reconnect), the client **SHALL** **immediately** (same lifecycle rules as today for “first moment outbound is allowed”) attempt to send one unsolicited outbound frame with `type` `device.online`, **without** waiting for any inbound text frame.
- **Online readiness** for outbound business traffic **SHALL** be defined by **transport open** (handshake complete, socket ready to send), not by `connected`.
- The **payload** of `device.online` **SHALL** remain the same JSON object as in `command.stat_response` **`payload.data`** (remote snapshot per `device-remote-snapshot`), not wrapped in `request_id` / `data`.
- Uses the **unified WebSocket envelope** (`v`, `type`, `id`, `ts`, `payload`) for `device.online`.
- **BREAKING** (coordination required): Servers or monitors that assumed the device waits for `connected` before being “online” must update to transport-open semantics; servers **SHOULD** stop sending `connected` per removed envelope requirement, but if they still send it, the device **MAY** ignore it for lifecycle (implementation detail).

## Capabilities

### New Capabilities

_(none — behavior extends existing WebSocket and snapshot contracts.)_

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative rules for outbound `device.online` (envelope + payload = remote snapshot object). **Remove** normative **Server connected payload** / `connected` message type from the contract.
- `device-websocket-connectivity`: **Remove** online gating by `connected`; define online readiness by **WebSocket transport open**; tie `device.online` timing to transport open; **modify** backoff-reset scenario to use transport open instead of `connected`.

## Impact

- **App**: `DeviceWebSocketConnectionManager` — stop transitioning to `ONLINE` from inbound `connected`; transition on **`onOpen`** (or equivalent) for the active socket; enqueue `device.online` immediately after open; remove or no-op `connected` dispatch for lifecycle; reuse snapshot builder as before.
- **Tests**: Update WS tests for online/`device.online` timing without `connected`; remove or repurpose tests that only assert `connected`-gated behavior.
- **Backend / ops**: Stop emitting `connected` if following the new contract; persist `device.online` as today for cache and user-app freshness. Coordinate rollout (device + server) because of **BREAKING** lifecycle change.
