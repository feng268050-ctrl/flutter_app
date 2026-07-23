## Context

**Settings → Device Information** (`DeviceInformationFragment` + `DeviceInfoViewModel`) shows machine identity and subsystem versions from Room `DeviceInfo`, Modbus/device status, and APK metadata. The industrial camera exposes a local HTTP API on port **9000** (see `CameraConfig.baseCameraAppUrl`, existing `CameraRemote.updateCameraTime` → `PUT …/System/time` with Basic auth).

The camera reports its software build in **`GET /System/deviceinfo`** JSON field **`appVersion`**. Host resolution must follow **`CameraConfig.getCameraHost(context)`** (user-overridable RTSP/host pref), not only the compile-time `CAMERA_IP` constant.

## Goals / Non-Goals

**Goals:**

- Last row on Device Information: label **Camera Version**, value = `appVersion` from deviceinfo when reachable.
- Fetch on entering / refreshing the screen; show **`-`** on any failure path.
- Reuse existing Retrofit + dynamic `@Url` pattern and camera Basic credentials (`CAMERA_USER_NAME` / `CAMERA_PASSWORD`) consistent with `CameraRemote`.

**Non-Goals:**

- Persisting camera version in `t_device_info` or MQTT/WS snapshots.
- Surfacing other deviceinfo fields (`deviceName`, `serialNumber`, etc.) in UI.
- Changing camera host configuration UX (Dev screen / prefs stay as-is).

## Decisions

1. **Data source and URL**
   - **Choice**: `GET {baseCameraAppUrl}System/deviceinfo` where `baseCameraAppUrl` = `CameraConfig.baseCameraAppUrl(context)` → `http://{getCameraHost}:9000/`.
   - **Rationale**: Matches documented camera API base and user-configured host; aligns with time sync URL construction.
   - **Alternative**: Hardcode `CameraConfig.CAMERA_IP` — rejected; ignores operator overrides.

2. **HTTP client**
   - **Choice**: Extend `CameraRemoteApi` with `@GET` + `@Url` (mirror `updateCameraTime`), implement fetch in `CameraRemote` or a small dedicated method called from the fragment/ViewModel.
   - **Rationale**: Same OkHttp/Retrofit stack, timeouts, and auth header pattern already proven for camera port 9000.
   - **Alternative**: Raw `HttpURLConnection` — rejected; inconsistent with codebase.

3. **Response model**
   - **Choice**: Gson DTO (e.g. `CameraDeviceInfo`) with `@SerializedName` for documented fields; UI reads only `appVersion`.
   - **Rationale**: Forward-compatible if we later show serial/MAC; strict null/empty check before display.
   - **Alternative**: Parse with `JsonObject` only — acceptable but DTO matches existing `CameraTime` style.

4. **UI binding**
   - **Choice**: `LiveData<String>` (or `ObservableField`) on `DeviceInfoViewModel` — e.g. `cameraVersionDisplay`, default **`-`**; load in `DeviceInformationFragment` `onViewCreated` / `onResume` via background callback.
   - **Rationale**: Camera version is not part of Room `DeviceInfo`; keeps entity unchanged.
   - **Alternative**: Room column — rejected per proposal (stale, wrong when camera swapped).

5. **Failure handling**
   - **Choice**: Any of: network failure, HTTP non-2xx, null body, blank `appVersion` → display **`-`**; log at debug/warn under existing camera log tag.
   - **Rationale**: User requirement; avoids flashing errors on disconnected camera VLAN.

6. **Auth**
   - **Choice**: Send `Authorization: Basic …` on GET if the camera requires it (same as time PUT). If production cameras allow unauthenticated GET, still send Basic for consistency unless integration testing shows 401 loops.
   - **Alternative**: No auth — verify on device; default to Basic to match `CameraRemote`.

7. **Localization**
   - **Choice**: Add `camera_version` string (EN + zh-CN valueset) for the label; value is API string or `-`.

## Risks / Trade-offs

- **[Slow or blocking UI]** → Mitigation: Retrofit `enqueue` on background thread; initial binding shows `-` until success.
- **[Camera returns 401 without auth]** → Mitigation: Match time-sync auth; if GET differs, adjust in implementation after hardware test.
- **[Stale version while screen open]** → Mitigation: Refetch on `onResume` optional; minimum fetch on first bind is sufficient for v1.
- **[Wrong host when camera on eth0 planner address]** → Mitigation: Use same `getCameraHost` as RTSP; document that Dev/camera host pref must match reachable IP.

## Migration Plan

- Ship in normal app release; no DB migration.
- Rollback: remove row and HTTP call only.

## Open Questions

- Confirm whether `GET /System/deviceinfo` requires Basic auth on target camera firmware (assume yes until proven otherwise).
