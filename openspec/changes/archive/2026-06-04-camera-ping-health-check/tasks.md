## 1. Ping health module

- [x] 1.1 Add `CameraPingHealth` singleton with atomic reachable flag, in-flight coalescing, and `ping -c 1 -W 1` probe on a background executor
- [x] 1.2 Add `probeAsync()`, `isReachable()`, and blocking `awaitReachable(timeoutMs)` APIs with test hooks
- [x] 1.3 Repurpose `CameraDeviceInfoRefreshScheduler` to `CameraPingHealthScheduler` (1 Hz tick calls `CameraPingHealth.probeAsync()` only; no HTTP)

## 2. Decouple comm status from version cache

- [x] 2.1 Update `CameraCommStatus` to derive fault/healthy from `CameraPingHealth` instead of `CameraDeviceInfoCache.getDisplay()`
- [x] 2.2 Update `CameraUtils.checkCamera` / `checkCameraBlocking` to use ping reachability with bounded timeout
- [x] 2.3 Verify `DeviceStatusPut`, `MonitorStatSnapshot`, and alarm fragments require no logic change beyond `CameraCommStatus` source swap

## 3. Version cache fetch-once with backoff

- [x] 3.1 Add cache-epoch tracking to `CameraDeviceInfoCache` (skip HTTP when valid version already cached)
- [x] 3.2 Implement exponential backoff retry sequence (1 s, 2 s, 4 s, 8 s, 16 s) for unresolved epochs with in-flight coalescing preserved
- [x] 3.3 Wire backoff start to existing triggers: `setCameraNetworkSegment` success, `clearAndRefresh`, app init when camera LAN is ready
- [x] 3.4 Ensure Settings Device Information explicit refresh still works via `refresh()` / `clearAndRefresh` without periodic HTTP

## 4. Application lifecycle

- [x] 4.1 Update `LaserApplication` to start/stop `CameraPingHealthScheduler` (replace deviceinfo scheduler references)
- [x] 4.2 Start version backoff fetch on startup paths that today call `CameraDeviceInfoCache.refresh` after eth0 setup (remove redundant periodic refresh calls)

## 5. Tests

- [x] 5.1 Unit tests for `CameraPingHealth` (success/failure/coalescing) and updated `CameraCommStatusTest`
- [x] 5.2 Update/rename `CameraDeviceInfoRefreshSchedulerTest` for ping scheduler (no HTTP on tick)
- [x] 5.3 Add `CameraDeviceInfoCache` backoff tests (success on later attempt, exhausted backoff, skip when cached)
- [x] 5.4 Adjust alarm/comm tests if any assert fault from version `-` while ping healthy

## 6. Verification

- [x] 6.1 Manual smoke: Monitor Camera tile and Alarm Comm Status follow ping unplug/replug, not version row
- [x] 6.2 Confirm logcat shows ~1 ping/s and no recurring `fetchDeviceInfoDisplay` after first successful version cache
