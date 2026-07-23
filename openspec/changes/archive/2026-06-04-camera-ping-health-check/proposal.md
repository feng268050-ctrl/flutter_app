## Why

The app currently probes camera communication every second via `GET /System/deviceinfo`, coupling connectivity health with version fetch and imposing unnecessary HTTP load on the IPC firmware. Network cameras may also need several seconds after eth0 setup before their HTTP service is ready, so a lightweight ping-based reachability check is sufficient for alarms and UI tiles, while version should be fetched once and cached after a bounded backoff retry sequence.

## What Changes

- Replace the **1 Hz HTTP deviceinfo periodic refresh** with a **1 Hz ICMP ping** to `CameraConfig.getCameraIp()` for camera communication health (`CameraCommStatus`, Monitor tiles, C002 alarm, WS/local stat snapshots).
- **Decouple** camera version (`CameraDeviceInfoCache`) from connectivity: HTTP `GET /System/deviceinfo` runs only until the first successful normalized `appVersion` is cached; no periodic re-fetch while the app process runs.
- On cache miss or after invalidation (eth0 segment setup, camera host change, explicit Settings refresh), fetch version with an **exponential backoff retry** (several attempts) to tolerate IPC HTTP startup delay.
- Update **`CameraUtils.checkCamera` / `checkCameraBlocking`** and NanoHTTPD camera gates to use ping reachability instead of deviceinfo refresh for connectivity.
- Retain existing version normalization, `CacheKey.CAMERA_VERSION_DISPLAY` notifications, and WS `deviceInfo.cameraVersion` semantics; version display `-` when fetch never succeeds does **not** imply communication fault once ping is healthy.

## Capabilities

### New Capabilities

- `camera-ping-health-check`: Periodic and on-demand ICMP ping probe to the configured camera IP, exposing healthy/fault state for comm status consumers.

### Modified Capabilities

- `camera-deviceinfo-periodic-refresh`: Replace 1 Hz HTTP deviceinfo timer with 1 Hz ping-based health probe (capability purpose/requirements updated; HTTP periodic refresh removed).
- `camera-version-deviceinfo-cache`: Remove periodic refresh requirement; add fetch-once-with-backoff for initial/invalidated cache population.
- `camera-communication-alarm`: Fault/recovery driven by ping health, not deviceinfo cache display `-`.
- `alarm-comm-status-platform-display`: Camera Comm Status indicator driven by ping health.
- `monitor-machine-status-camera-card`: Camera tile checkbox driven by ping health.

## Impact

- **Core modules**: `CameraDeviceInfoRefreshScheduler` (repurpose or replace), new ping health module, `CameraCommStatus`, `CameraDeviceInfoCache`, `CameraUtils`.
- **Startup / network**: `LaserApplication`, `SystemSettingUtils.setCameraNetworkSegment`, Wi-Fi / AI Vision prep hooks that today trigger deviceinfo refresh.
- **UI / alarms**: `WarnInfoFragment`, `MachineStatusBaseFragment`, `CommStatusBindingAdapter`, `DeviceStatusPut`, `MonitorStatSnapshot`.
- **Tests**: Scheduler tests, `CameraCommStatusTest`, cache backoff tests, alarm transition tests.
- **Docs**: Optional note in `docs/camera-eth0-topology.md` on ping vs HTTP responsibilities.
