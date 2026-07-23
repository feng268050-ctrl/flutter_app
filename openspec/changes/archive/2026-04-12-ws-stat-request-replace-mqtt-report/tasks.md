## 1. Model and naming

- [x] 1.1 Add a transport-neutral DTO (e.g. `DeviceRemoteSnapshot`) with fields matching the former packed aggregate minus `device`; avoid MQTT/MQ in type and package names.
- [x] 1.2 Add mapping from `DeviceStatusPut.packVoData` (or equivalent) to the new DTO, explicitly omitting `device` and any unused identity blob.
- [x] 1.3 Rename `applyInstalledAppVersionForMqtt` (and similar) to a neutral name if still used for snapshot assembly; update call sites.

## 2. WebSocket handling

- [x] 2.1 In `DeviceWebSocketConnectionManager` (or central WS dispatcher), handle inbound `type` `command.stat_request` after session is valid/online per existing rules.
- [x] 2.2 Build snapshot on a worker thread if assembly touches DB or heavy work; marshal result back to send on the WS writer thread per existing patterns.
- [x] 2.3 Send `command.stat_response` with unified envelope: new top-level `id`, `v`/`ts`, and `payload` `{ "request_id": <inbound id>, "data": <snapshot JSON object> }`.
- [x] 2.4 Log and safely ignore malformed `command.stat_request` frames (log protocol error, do not crash).

## 3. Remove MQTT periodic upload

- [x] 3.1 Remove `startDeviceCacheDto` and its call from `initMQTT` (or rename/init flow) so the 60s timer no longer registers.
- [x] 3.2 Remove `TimingJobType.MQTT_UP_DEVICE_STATUS` and any `TimingJobTaskManager` wiring used only for that task.
- [x] 3.3 Remove `DeviceInfoMq` publish from this path; delete unused imports and dead code paths in `LaserApplication` tied solely to MQTT device-info push.

## 4. Verification

- [x] 4.1 Manual or integration check: inject `command.stat_request` and assert outbound `command.stat_response` shape (`request_id`, `data` without `device`).
- [x] 4.2 Confirm no periodic MQTT publish for device info remains (log/grep for `publishToSys` with `DeviceInfoMq` from timer).
- [x] 4.3 Run existing unit/instrumentation tests touching WS and MQTT startup paths; fix regressions.
