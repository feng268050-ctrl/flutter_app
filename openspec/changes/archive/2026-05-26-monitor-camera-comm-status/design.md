## Context

- **Machine Status** (`MachineStatusFragment` / `fragment_machine_status.xml`) shows six Modbus-driven toggle cards (laser, blow, safety lock, gun switch, red light, wire feed) in a 4-column `GridLayout`, plus two gauge charts.
- **Alarm Information** Welding Gun section uses `commStatus*` binding on Gun Comm Status (`deviceStatus.isGunCommunicationAlarm`) with platform-aware three-state display (`CommStatusDisplay` + `CommStatusBindingAdapter`).
- Camera software version uses **`CameraDeviceInfoCache`** → `GET {CameraConfig.BASE_CAMERA_APP_URL}System/deviceinfo`, normalized `appVersion`, sentinel `-` on failure. Refresh today runs on eth0 segment success, host change, and Settings Device Information open/resume—not on a fixed interval.
- Comm alarms from Modbus flow through **`DeviceStatusConvert`** into `WarnTable` / `createNormalHit` / dialog pipeline (`H001` gun, `W001` feeder, `H0022` laser, etc.).

## Goals / Non-Goals

**Goals:**

- Surface camera link health on Monitor (Machine Status card + Alarm Information comm tile).
- Keep a single HTTP source of truth via `CameraDeviceInfoCache.refresh` at 1 Hz app-wide.
- Raise/clear camera comm alarms with logging and operator popup consistent with existing comm faults.

**Non-Goals:**

- New Modbus bits or lower-controller firmware changes.
- Persisting camera comm state in Room.
- Replacing eth0 setup or RTSP health checks; HTTP deviceinfo remains the comm probe.
- Emulator-specific skipping of the 1 Hz timer (timer may run; display rules already neutralize comm tiles on emulator).

## Decisions

1. **Connectivity signal**
   - **Choice**: Treat camera comm as **healthy** when `CameraDeviceInfoCache.getDisplay()` is not `CameraRemote.CAMERA_VERSION_UNAVAILABLE` (`"-"`); **fault** when display is `-` after the latest refresh attempt completed (success or failure).
   - **Rationale**: Matches Settings Camera Version semantics and existing cache contract; no parallel ping/RTSP probe.
   - **Alternative**: Separate boolean on cache — rejected as redundant with display sentinel.

2. **Expose comm fault to UI binding**
   - **Choice**: Add `CameraCommStatusProvider` (or static helper on cache) returning `boolean isCameraCommunicationFault()`; bind Machine Status checkbox as `checked = !fault` (or dedicated inverse binding). Alarm tile uses `commStatusAlarm="@{cameraCommFault}"` with same adapter as gun/feeder.
   - **Rationale**: Camera fault is not on `DeviceStatus`; avoid polluting Modbus entity.
   - **Alternative**: Synthetic `DeviceStatus` field — rejected.

3. **UI refresh on cache updates**
   - **Choice**: `MemoryCacheManager` listener on `CacheKey.CAMERA_VERSION_DISPLAY` in `MachineStatusBaseFragment`, `WarnInfoFragment`, and alarm monitor component; post binding invalidate / `setCameraCommFault` when key changes.
   - **Rationale**: Existing pattern for device status/data; 1 Hz updates already notify via `putString`.

4. **Global 1 Hz refresh**
   - **Choice**: `Handler` on main looper in `LaserApplication` with `postDelayed` 1000 ms loop calling `CameraDeviceInfoCache.refresh(app)`; start after `AppRuntimeEnvironment.init`, cancel on `onTerminate` (best-effort). Rely on cache in-flight guard so overlapping ticks do not stack HTTP.
   - **Rationale**: User requirement; minimal new infrastructure vs `TimingJobTask` Modbus scheduler.
   - **Alternative**: Extend `TimingJobTaskManager` — heavier coupling to Modbus timing jobs.

5. **Welding Gun layout**
   - **Choice**: Row 0: Gun Comm Status (`column 0`) + Camera Comm Status (`column 1`); row 1: gun motor temp + driver board temp unchanged.
   - **Rationale**: User asked for Camera Comm Status after Gun Comm Status; matches Laser Device / Wire Feeder two-column comm rows.

6. **Machine Status Camera card**
   - **Choice**: Seventh tile in grid (new row), label `@string/camera_title`, background asset consistent with `machine_data*` series (reuse `machine_data7` or next available mipmap), checkbox reflects comm healthy (checked = connected).
   - **Rationale**: Parity with other on/off indicators; camera has no Modbus on/off bit.

7. **Alarm code and pipeline**
   - **Choice**: New **`C002`** / `AlarmCodeEnums.C002` with title/content strings for **industrial camera HTTP communication**. The **C** prefix denotes **communication (通讯)** alarms. **`C001`** is not used by the app alarm pipeline—it is already defined in the laser `warn_code` resource table (temperature-control board ↔ refrigeration system). Camera comm is the next C-series slot: **`C002`**.
   - **Choice**: Integrate in `DeviceStatusConvert.convertToWarnTables` and realtime `createNormalHit` path driven by cache fault boolean (not `DeviceStatus`). Log via existing warn/exception logging used by `H001`.
   - **Rationale**: Aligns with product naming; avoids reusing gun `H001` or laser `C001`.
   - **Alternative**: Reuse generic network alarm — rejected for traceability.

8. **Emulator behavior**
   - **Choice**: Camera Comm Status tile follows `alarm-comm-status-platform-display` (neutral gray on emulator when fault; healthy when cache has version on emulator if dev camera reachable).
   - **Rationale**: Consistency with Pump/Gun/Feeder; archived spec already defines rules.

## Risks / Trade-offs

- **[HTTP load 1 req/s]** → Mitigation: `refreshInFlight` coalescing; failed requests still at most one outstanding.
- **[False fault before eth0 ready]** → Mitigation: Display stays `-` until first success; acceptable same as Settings; eth0 setup still triggers immediate refresh on segment success.
- **[Alarm flapping on flaky Wi-Fi]** → Mitigation: Follow existing comm alarm debounce if present; otherwise accept same behavior as feeder comm (document; optional debounce in implementation tasks).
- **[Machine Status grid 7th tile layout]** → Mitigation: Match dimens/margins of row 1 tiles; verify 1920×1080 monitor layout in QA.

## Migration Plan

- App release only; no DB migration.
- New alarm code `C002` appears in warn logs; servers unchanged.
- Rollback: Remove timer, UI tiles, and `C002` hooks; cache continues event-driven refresh.

## Open Questions

- Debounce duration for camera comm popup if operators report chatter on borderline LAN (default: none, match `W001`).
