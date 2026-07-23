## Why

Remote operators and cloud services read camera firmware from WebSocket snapshots (`device.online` and `command.stat_response`), but today `deviceInfo` omits camera software version. Settings can probe the camera on demand, yet that path is screen-local and not shared with snapshot builders—so support sees incomplete identity on connect and stat polls.

## What Changes

- Add **`cameraVersion`** to the `deviceInfo` object inside the remote snapshot (`device.online` `payload.stat.deviceInfo` and `command.stat_response` `payload.data.deviceInfo`), using the same normalized value as Settings (from camera `GET /System/deviceinfo` `appVersion`).
- Introduce a **unified fetch-and-cache** path for camera deviceinfo: one module loads after camera LAN is ready, stores the normalized version in memory, and all consumers (Settings UI, `DeviceStatusPut` / snapshot pack) read from cache.
- Trigger cache refresh when **`setCameraNetworkSegment`** successfully configures `eth0` for the camera /24 (tablet IP derived from camera host), and on other existing camera-network entry points as needed (app startup, Wi-Fi callback, AI Vision prep).
- When cache is empty or fetch failed, snapshot and UI SHALL emit **`cameraVersion` as `-`** (or omit only if product explicitly chooses omit-on-missing—default **`-`** for parity with Settings).
- Refactor Settings **Device Information** to use the cache (optional refresh on screen open) instead of a one-off HTTP call isolated in the ViewModel.
- Update **`docs/network-api-reference.md`** with `deviceInfo.cameraVersion` on remote snapshot payloads.

## Capabilities

### New Capabilities

- `camera-version-deviceinfo-cache`: Unified in-memory cache for camera `appVersion`, populated after camera eth0 segment setup, consumed by WS `deviceInfo` and Settings.

### Modified Capabilities

- `device-remote-snapshot`: `deviceInfo` in remote snapshot JSON SHALL include `cameraVersion` with defined semantics and fallback.
- `device-info-camera-version`: Settings row SHALL read from the shared cache; requirement extended so the same normalized value appears in remote `deviceInfo` (delta spec under this change).

## Impact

- **Network / camera**: `CameraRemote`, `SystemSettingUtils.setCameraNetworkSegment`, possible `CacheKey` for camera version string or full `CameraDeviceInfo`.
- **WS / snapshot**: `DeviceStatusPut.getDeviceInfo`, `DeviceInfo` entity (`@Ignore` field `cameraVersion` for Gson only—no Room column).
- **UI**: `DeviceInfoViewModel` / `DeviceInformationFragment` bind to cache.
- **Tests**: `DeviceRemoteSnapshotTest`, `CameraRemoteTest`, cache refresh hook tests.
- **Docs**: `docs/network-api-reference.md`, optional `docs/camera-eth0-topology.md` note on prefetch timing.
