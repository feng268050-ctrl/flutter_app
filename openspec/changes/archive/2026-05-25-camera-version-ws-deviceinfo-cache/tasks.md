## 1. Cache and fetch layer

- [x] 1.1 Add `CacheKey.CAMERA_VERSION_DISPLAY` (or equivalent) and `CameraDeviceInfoCache` with `getDisplay()`, `refresh(Context)`, in-flight coalescing, and writes via `CameraRemote` normalization
- [x] 1.2 Refactor `CameraRemote.fetchCameraAppVersion` to delegate to cache refresh or share internal GET handler used only by cache
- [x] 1.3 Unit-test cache: success stores normalized value, failure stores `-`, concurrent refresh coalesces

## 2. Prefetch hooks

- [x] 2.1 Invoke `CameraDeviceInfoCache.refresh` from `SystemSettingUtils.setCameraNetworkSegment` after successful eth0 addr + route setup
- [x] 2.2 Invoke refresh when camera host preference changes (Dev / settings save path for `PREF_CAMERA_RTSP_HOST`)
- [x] 2.3 Document prefetch timing in `docs/camera-eth0-topology.md` (optional one-line cross-link)

## 3. Remote snapshot and model

- [x] 3.1 Add `@Ignore String cameraVersion` on `DeviceInfo` (Gson field `cameraVersion`)
- [x] 3.2 In `DeviceStatusPut.getDeviceInfo`, set `cameraVersion` from `CameraDeviceInfoCache.getDisplay()` before snapshot serialization
- [x] 3.3 Extend `DeviceRemoteSnapshotTest` (or snapshot JSON test) asserting `deviceInfo.cameraVersion` for populated cache and `-` fallback

## 4. Settings UI

- [x] 4.1 Update `DeviceInfoViewModel` / `DeviceInformationFragment` to bind Camera Version from cache; optional `refresh` on resume
- [x] 4.2 Remove or slim duplicate per-screen-only HTTP path that bypasses cache

## 5. Documentation

- [x] 5.1 Update `docs/network-api-reference.md` — `deviceInfo.cameraVersion` on `device.online` / `command.stat_response` payloads

## 6. Verification

- [x] 6.1 Manual: after boot/eth0 setup, `device.online` JSON includes `deviceInfo.cameraVersion` when camera reachable
- [x] 6.2 Manual: `command.stat_response` `deviceInfo.cameraVersion` matches Settings row after cache populated
- [x] 6.3 Manual: camera offline → WS and Settings show `-`
