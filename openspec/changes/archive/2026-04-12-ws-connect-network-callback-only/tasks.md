## 1. Spec and docs alignment

- [x] 1.1 Confirm `openspec/changes/ws-connect-network-callback-only/specs/device-websocket-connectivity/spec.md` matches intended product behavior; archive flow will merge into `openspec/specs/device-websocket-connectivity/spec.md`.

## 2. Remove Application startup WS connect

- [x] 2.1 Remove `DeviceWebSocketConnectionManager.getInstance().connectOrReconnect("app_startup")` from `LaserApplication` (delete `initDeviceCloudConnection()` or strip it to a no-op and remove its call from `initBaseHardware()` if nothing else remains).

## 3. Simplify connection manager dedup

- [x] 3.1 After §2, review `DeviceWebSocketConnectionManager.connectOrReconnect` duplicate-connect short-circuit (`sameTarget` + `CONNECTING`/`ONLINE`); remove it if safe, or shrink to the minimum needed to avoid handshake churn (document the choice in code comment).

## 4. Verification

- [x] 4.1 Grep for `connectOrReconnect("app_startup")` and any tests/docs asserting startup ordering; update or delete stale expectations.
- [x] 4.2 Run targeted unit tests touching `DeviceWebSocketConnectionManager` / WS connectivity; fix failures caused by lifecycle change.
