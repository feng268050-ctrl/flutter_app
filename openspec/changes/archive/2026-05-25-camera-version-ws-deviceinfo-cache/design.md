## Context

- **Settings** already fetches camera `appVersion` via `CameraRemote.fetchCameraAppVersion` on Device Information open (`device-info-camera-version` capability).
- **WebSocket** remote snapshots are built by `DeviceStatusPut.packRemoteSnapshot` → `deviceInfo` from Room/cache `DeviceInfo` without camera fields.
- **Camera LAN** is established by `SystemSettingUtils.setCameraNetworkSegment`: derives tablet `eth0` IP from `CameraConfig.getCameraHost` and current Wi-Fi IP via `CameraEth0AddressPlanner`, then applies `ip addr` / route. This runs at app startup (`LaserApplication`), on Wi-Fi changes (`CameraEth0WifiNetworkCallback`), before RTSP (`EasyPlayerClientManger`, `AiVisionFragment`), and elsewhere.
- Camera HTTP API: `GET {baseCameraAppUrl}System/deviceinfo` with Basic auth; normalize `appVersion` in `CameraRemote.parseCameraAppVersionDisplayValue`.

## Goals / Non-Goals

**Goals:**

- Single **prefetch + cache** for normalized camera version string.
- Populate cache after successful camera segment setup (or best-effort async immediately following `setCameraNetworkSegment` when eth0 config commands succeed).
- Inject `deviceInfo.cameraVersion` into `device.online` and `command.stat_response` snapshots.
- Settings **Camera Version** row reads the same cache (optional explicit refresh on screen resume).

**Non-Goals:**

- Room migration or persisting camera version in `t_device_info`.
- Exposing full `CameraDeviceInfo` on the wire (only `cameraVersion` string).
- Blocking `setCameraNetworkSegment` on HTTP completion (prefetch is async).
- Changing `command.stat_response` / `device.online` envelope shape beyond `deviceInfo`.

## Decisions

1. **Cache store**
   - **Choice**: Add `CacheKey.CAMERA_VERSION_DISPLAY` (String) in `MemoryCacheManager`, written only by a new `CameraDeviceInfoCache` (or methods on `CameraRemote`) after successful deviceinfo fetch. Initial/absent value treated as `-`.
   - **Rationale**: Matches `systemVersion` pattern (`@Ignore` on `DeviceInfo` filled at pack time); avoids Room; thread-safe enough for snapshot reads if writes use same manager as other caches.
   - **Alternative**: Cache full `CameraDeviceInfo` — deferred; only version needed today.

2. **Unified fetch entry**
   - **Choice**: `CameraDeviceInfoCache.refresh(Context)` wraps existing `CameraRemote` GET + normalization, updates `CacheKey`, logs once per outcome. Idempotent in-flight guard (single outstanding request) to avoid storms when Wi-Fi flaps.
   - **Rationale**: One API for Settings, eth0 hook, and manual retry.
   - **Alternative**: Only hook eth0 — insufficient for Settings opened before eth0; still allow explicit `refresh` from fragment.

3. **When to prefetch**
   - **Choice**: Call `refresh` at end of `setCameraNetworkSegment` when `addrAdded && routeOk` (or after try block success path). Also call from `LaserApplication` startup path that already invokes `setCameraNetworkSegment` (no duplicate if segment method already triggers refresh).
   - **Rationale**: User requirement—after tablet IP is derived and eth0 is on-camera-LAN, HTTP to camera host is routable.
   - **Alternative**: Delay until first RTSP frame — later and misses early `device.online`.

4. **Snapshot field**
   - **Choice**: Add `@Ignore private String cameraVersion` on `DeviceInfo`; `DeviceStatusPut.getDeviceInfo` sets it from `CameraDeviceInfoCache.getDisplay()` (never from Room). JSON key `cameraVersion` via default Gson field name.
   - **Rationale**: Keeps `deviceInfo` subtree consistent; no new snapshot root field.
   - **Alternative**: Root-level `cameraVersion` — rejected; product asked for `deviceInfo`.

5. **Fallback**
   - **Choice**: Missing cache or failed fetch → `cameraVersion` is `"-"` in JSON (same as Settings placeholder `CameraRemote.CAMERA_VERSION_UNAVAILABLE`).
   - **Rationale**: Explicit sentinel for servers; matches UI.

6. **Settings integration**
   - **Choice**: `DeviceInfoViewModel` observes cache / reads on init; `DeviceInformationFragment` may call `refresh` on `onResume` to pick up post-eth0 updates.
   - **Rationale**: Removes duplicate HTTP in ViewModel; UI stays fresh after background prefetch.

7. **Stale cache on host change**
   - **Choice**: When `CameraConfig.PREF_CAMERA_RTSP_HOST` changes (Dev screen save), call `refresh` and clear prior cache value first.
   - **Rationale**: Operator may point at different camera IP.

## Risks / Trade-offs

- **[Race: device.online before prefetch completes]** → `cameraVersion` is `-` until refresh completes; acceptable for first seconds after boot; stat polls later see updated value.
- **[eth0 setup fails, prefetch still runs]** → Request may fail; cache stays `-`; same as unreachable camera.
- **[Duplicate refresh from Wi-Fi + startup]** → Mitigation: in-flight guard in cache helper.
- **[Spec drift vs device-info-camera-version]** → Delta spec clarifies Settings uses cache; main spec archived requirement “runtime only on screen” is relaxed for cache but not Room.

## Migration Plan

- App release only; no DB migration.
- **Server consumers**: May start reading `deviceInfo.cameraVersion`; absent on old builds — treat missing as unknown.
- Rollback: Remove field population and eth0 hook; Settings can revert to direct fetch.

## Open Questions

- Should failed fetch retry with backoff on a timer, or only on eth0/Wi-Fi/host-change events? **Default**: refresh on segment success + host change + Settings resume only.
- Confirm JSON key `cameraVersion` with backend (vs `cameraAppVersion`). **Default**: `cameraVersion` per user message.
