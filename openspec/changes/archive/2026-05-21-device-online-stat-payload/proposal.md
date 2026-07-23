## Why

The platform server and companion apps already consume device status through `command.stat_response` (`payload.data` holds the remote snapshot). Today `device.online` places that snapshot **directly** on `payload`, so consumers need a separate parsing path for connect-time uplink. Nesting the same snapshot under `payload.stat` lets the server reuse one field path for proactive and on-demand status while keeping `command.stat_response` correlation fields (`request_id`, `data` wrapper) unchanged.

## What Changes

- **BREAKING**: `device.online` `payload` is no longer the remote snapshot root object. It becomes `{ "stat": <remote snapshot> }`, where **`stat` deep-equals `command.stat_response` `payload.data`** (same JSON object; no `request_id` or extra `data` wrapper on `stat`).
- Reuse the existing snapshot builder (`DeviceStatusPut.packRemoteSnapshot` / `buildSnapshotDataMap`) so `payload.stat` matches a contemporaneous `command.stat_response` `payload.data`.
- Update docs (`docs/device-websocket-migration.md`, `docs/network-api-reference.md`) and tests for the new envelope shape.

## Capabilities

### New Capabilities

<!-- None -->

### Modified Capabilities

- `device-ws-unified-envelope`: Redefine **Outbound device online snapshot envelope** — `payload.stat` is the remote snapshot object.
- `device-remote-snapshot`: Update normative paths from `device.online` `payload` root to `device.online` `payload.stat` for snapshot field rules.
- `device-websocket-connectivity`: Update `device.online` timing/scenarios that refer to snapshot-as-`payload`.

## Impact

- **App**: `DeviceWebSocketConnectionManager.sendDeviceOnline` — set `payload.stat` to the snapshot map; share serialization with `sendStatResponse`.
- **Tests**: `DeviceWebSocketConnectionTest` and any integration tests asserting `device.online` JSON shape.
- **Docs**: WebSocket migration guide and network API reference.
- **Backend / ops**: **BREAKING** for consumers that read snapshot fields from `device.online` `payload` root; must read `payload.stat` instead. Coordinate rollout with server changes.
