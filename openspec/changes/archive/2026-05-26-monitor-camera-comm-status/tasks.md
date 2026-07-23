## 1. Cache and connectivity helper

- [x] 1.1 Add `CameraCommStatus` helper (e.g. `isFault()` from `CameraDeviceInfoCache.getDisplay() == "-"` ) for UI and alarms
- [x] 1.2 Add `CameraDeviceInfoRefreshScheduler` in `LaserApplication`: 1 Hz `Handler` loop calling `CameraDeviceInfoCache.refresh(app)`; cancel on process teardown
- [x] 1.3 Unit-test scheduler coalescing interaction with `CameraDeviceInfoCache` in-flight guard (or extend `CameraDeviceInfoCacheTest`)

## 2. Alarm code and pipeline

- [x] 2.1 Add `C002` (C-series = 通讯) to `AlarmCodeConstants`, `AlarmCodeEnums`, and strings (EN/ZH) for camera communication alarm title/content
- [x] 2.2 Wire `DeviceStatusConvert` (warn table + realtime hit) to camera comm fault via cache listener or dedicated monitor component
- [x] 2.3 Ensure popup debounce matches gun/feeder comm (no repeat while C002 active); log exception on fault transition

## 3. Monitor — Machine Status

- [x] 3.1 Add Camera card to `fragment_machine_status.xml` (label `camera_title`, checkbox bound to comm healthy)
- [x] 3.2 Register `CAMERA_VERSION_DISPLAY` listener in `MachineStatusBaseFragment` and refresh binding on cache change
- [x] 3.3 Verify layout on 1920×1080 with seventh tile in grid

## 4. Monitor — Alarm Information

- [x] 4.1 Add `camera_comm_status_text` strings (EN/ZH/default)
- [x] 4.2 Update `fragment_warn_info.xml` Welding Gun grid: row 0 col 1 Camera Comm Status tile with `commStatus*` bindings + `cameraCommFault` variable
- [x] 4.3 Update `WarnInfoFragment` binding: expose `cameraCommFault`, listen to `CAMERA_VERSION_DISPLAY`, keep `emulator`/`statusReady`
- [x] 4.4 Adjust row/column indices for temperature tiles per updated layout spec

## 5. Tests and validation

- [x] 5.1 Extend `CommStatusDisplayTest` or add tests for camera fault + emulator matrix
- [x] 5.2 Add unit test for `CameraCommStatus` / C002 convert path (fault ↔ healthy)
- [ ] 5.3 Manual QA: Settings Camera Version, Machine Status card, Alarm tile, popup on disconnect, recovery on reconnect
