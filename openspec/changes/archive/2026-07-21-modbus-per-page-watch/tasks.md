## 1. Client and AppServices (poll-only ensure)

- [x] 1.1 Slim `ModbusRtuClient`: add poll ensure + `watchAttributes` / `watchHealth` passthrough; remove or gut `startLiveDemo` shared-watch behavior (move optional `info` group read to callers that need it)
- [x] 1.2 Change `AppServices.ensureModbusLive` to poll-only (keep capability + boot-self-check intercept / defer); remove `watchIds` parameter and attribute/health broadcast controllers (or stop using them)
- [x] 1.3 Keep `scheduleEnsureModbusLive` / Home-after-self-check / Monitor / Settings / Demo route ensure as poll-only entry points; update dartdocs

## 2. Per-surface watches

- [x] 2.1 `GunAlarmTelemetry`: subscribe with Monitor id list via `watchAttributes`; subscribe `watchHealth` if needed; cancel on dispose; stop using `modbusAttributeChanges`
- [x] 2.2 `DeviceInformationTab`: watch device Modbus field ids; optional one-shot `info` / attribute prime; cancel on dispose
- [x] 2.3 `P2DemoPage`: under AppScope, watch Demo tile ids (+ health for Modbus Link); no AppScope path keeps private client watch; cancel on dispose
- [x] 2.4 Grep and migrate any remaining listeners of `modbusAttributeChanges` / `modbusHealthChanges` / `startLiveDemo`

## 3. HAL coverage / tests

- [x] 3.1 Add or extend `cyber_hal` test: two concurrent `watchAttributes` with different `ids` get filtered emissions; cancel one leaves poll + peer
- [x] 3.2 Update App widget/unit tests that assumed broadcast or `startLiveDemo` wiring
- [x] 3.3 `flutter analyze` on `app/hmi` and `packages/cyber_hal`; run affected tests

## 4. Device smoke

- [x] 4.1 `make build-app` && `make push-app`; verify Home self-check then Monitor temps/alarms without opening Demo first; Settings Device Info updates; `/proc/tty/driver/serial` ttyS5 traffic while on Home after self-check
