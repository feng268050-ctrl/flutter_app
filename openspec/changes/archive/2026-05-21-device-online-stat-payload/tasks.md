## 1. WebSocket payload implementation

- [x] 1.1 Refactor `DeviceWebSocketConnectionManager` to build shared snapshot `data` map (reuse `snapshotToMap`) for both `sendStatResponse` and `sendDeviceOnline`
- [x] 1.2 Change `sendDeviceOnline` to emit `payload` as `{ "stat": <snapshot> }` (same object as `command.stat_response` `payload.data`)
- [x] 1.3 Update class/method Javadoc on `sendDeviceOnline` to describe the `stat` wrapper

## 2. Tests

- [x] 2.1 Update `DeviceWebSocketConnectionTest` (assert `payload.stat` is snapshot, no flat fields at `payload` root, no `request_id`/`data` on `stat`)
- [x] 2.2 Add test asserting `device.online` `payload.stat` deep-equals `command.stat_response` `payload.data` for the same snapshot input

## 3. Documentation

- [x] 3.1 Update `docs/device-websocket-migration.md` `device.online` section: `payload.stat` shape, **BREAKING** note for flat `payload` consumers
- [x] 3.2 Update `docs/network-api-reference.md` references from `device.online` `payload` root to `payload.stat`

## 4. Verification

- [x] 4.1 Run unit tests for `DeviceWebSocketConnectionTest` (and related WS tests if any)
- [x] 4.2 Coordinate with backend that server reads `payload.stat` before device rollout
