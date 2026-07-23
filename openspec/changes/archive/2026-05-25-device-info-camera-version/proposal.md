## Why

Operators troubleshooting the HMI and camera stack need the **installed camera firmware/app version** on the same screen as other device identity fields. That value lives on the camera over its local HTTP API (`appVersion` in `System/deviceinfo`), not in Room or Modbus today, so it is invisible in **Settings → Device Information**.

## What Changes

- Add a **Camera Version** row as the **last** field on the Device Information screen (after Wire Feeder Version).
- On screen load (or equivalent lifecycle), **GET** `http://{cameraHost}:9000/System/deviceinfo` using the configured camera host (`CameraConfig.getCameraHost` / `baseCameraAppUrl`), parse JSON `appVersion`, and display it.
- If the request fails (camera offline, timeout, non-success HTTP, malformed body, missing `appVersion`), display **`-`**.
- Do **not** persist camera version in Room `DeviceInfo`; it is a runtime probe only (same class of data as other camera HTTP utilities).

## Capabilities

### New Capabilities

- `device-info-camera-version`: Settings Device Information shows camera `appVersion` from `GET /System/deviceinfo` with fallback `-` on failure.

### Modified Capabilities

- (none)

## Impact

- **UI**: `fragment_device_information.xml`, string resources (`camera_version` or equivalent EN/ZH).
- **Logic**: `DeviceInformationFragment` and/or `DeviceInfoViewModel` — async fetch and binding for the new row.
- **Network**: `CameraRemoteApi` / `CameraRemote` (or parallel helper), new Gson model for deviceinfo response (`appVersion` and optional fields per API).
- **Config**: `CameraConfig.baseCameraAppUrl` + `System/deviceinfo` path (host from prefs, not hardcoded default only).
- **Docs**: `docs/network-api-reference.md` optional note for the new endpoint usage.
