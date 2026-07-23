## Why

Operators need the same visibility into industrial camera connectivity on **Monitor** that they already have for pump, gun, and feeder Modbus peripherals. Camera health is today only implied indirectly via **Settings → Device Information → Camera Version** (HTTP `deviceinfo` cache) and is not polled continuously, so Monitor cannot show live comm state or raise operator-facing alarms when the camera LAN link fails.

## What Changes

- Add a **Camera** status card on **Monitor → Machine Status**, aligned with existing machine status tiles (checkbox on/off style), reflecting whether the unified camera `deviceinfo` cache reports a reachable camera (normalized version not `-`).
- On **Monitor → Alarm Information**, in the **Welding Gun** group, add **Camera Comm Status** immediately after **Gun Comm Status** (same two-column comm tile pattern and `commStatus*` binding adapter as Pump/Gun/Feeder).
- Start a **process-wide 1 Hz timer** in `LaserApplication` (or equivalent app lifecycle owner) that calls `CameraDeviceInfoCache.refresh(Context)` so the cache stays current for Monitor, Settings, and WebSocket `deviceInfo.cameraVersion` without duplicate HTTP clients.
- When camera communication is abnormal (cache display `-` after failed/unreachable `deviceinfo`), **log an exception record** and show a **popup warning** using the same alarm pipeline as gun/feeder/laser comm faults. Use alarm code **`C002`** under the **C = communication (通讯)** series (`C001` is reserved in the laser module fault table for temperature-control ↔ refrigeration comm; camera uses the next free C-series slot).
- Extend **alarm-information-left-panel-layout** so Welding Gun row 0 holds Gun Comm Status and Camera Comm Status side by side; temperature tiles remain on row 1.

## Capabilities

### New Capabilities

- `monitor-machine-status-camera-card`: Camera tile on Machine Status driven by camera comm connectivity (not Modbus).
- `camera-deviceinfo-periodic-refresh`: App-wide 1 s polling via unified cache refresh API with in-flight coalescing preserved.
- `camera-communication-alarm`: Exception log + modal alarm when camera HTTP comm is down; clear when cache recovers.

### Modified Capabilities

- `alarm-information-left-panel-layout`: Welding Gun first row is two comm tiles (Gun + Camera); second row unchanged (two temperatures).
- `alarm-comm-status-platform-display`: Include Camera Comm Status in three-state emulator/production rules (same as Pump/Gun/Feeder).
- `camera-version-deviceinfo-cache`: Document that refresh is also driven by global 1 Hz timer while app is running, not only eth0/Settings events.

## Impact

- **UI**: `fragment_machine_status.xml`, `fragment_warn_info.xml`, `MachineStatusBaseFragment` / `MachineStatusFragment`, `WarnInfoFragment`, `CommStatusBindingAdapter` consumers, new strings (`camera_comm_status_text`, camera comm alarm copy).
- **App lifecycle**: `LaserApplication` (start/stop periodic refresh on main process).
- **Cache / HTTP**: `CameraDeviceInfoCache`, `CameraRemote` (reuse only; no second fetch path).
- **Alarms**: `DeviceStatusConvert`, `AlarmCodeConstants` / `AlarmCodeEnums`, optional `CameraCommStatusMonitor` or hook from cache listener; warn log + dialog parity with `H001` / `W001`.
- **Tests**: Unit tests for comm display resolution, cache-driven fault detection, layout binding smoke tests where applicable.
- **Non-goals**: Modbus register changes, camera host override UI, changing `GET /System/deviceinfo` contract.
