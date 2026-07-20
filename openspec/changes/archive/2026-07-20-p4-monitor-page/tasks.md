## 1. Scaffold & navigation

- [x] 1.1 Add `AppRoutes.monitor` (`/monitor`) and register the route in `LwsHmiApp` / navigation
- [x] 1.2 Create `features/monitor/` layout (`domain` / `application` / `presentation`)
- [x] 1.3 Add a visible Monitor entry on Home that `pushNamed`s to `/monitor`

## 2. Shared Modbus watch helper

- [x] 2.1 Extract temperature + over-temp + alarm attribute watching from `HomeTemperatureCard` into an application-layer helper (explicit `watchAttributes` id allowlist per design D2/D4)
- [x] 2.2 Wire helper through `AppServices.ensureModbusLive()`; soft-fail to `-`; optional `watchHealth` surface
- [x] 2.3 Point Home temperature card at the shared helper (behavior parity)

## 3. Monitor UI (Material)

- [x] 3.1 Implement Monitor page shell (Material) with Alarm Information section (four gun temp rows + over-temp styling)
- [x] 3.2 Implement active alarm list (true `alarm.*` with `meta.alarm_code`; show code + label; remove when false)
- [x] 3.3 Ensure first paint is not blocked on Modbus; delay/start watch after first frame like Home

## 4. Config & verification

- [x] 4.1 Confirm design inventory ids exist in `assets/hal/modbus.json`; add any missing attributes via config only (no UI addresses)
- [x] 4.2 Run `flutter analyze` under pinned SDK for touched Dart; add lightweight unit/widget tests for alarm list filtering / temp display helpers where practical
- [x] 4.3 Device smoke: `make build-app` + `make push-app` (or debug-app) — Monitor opens, dashes without slave; with slave, temps and alarms update
