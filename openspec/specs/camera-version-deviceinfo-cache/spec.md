## Purpose

Maintain a single in-memory normalized camera software version from `GET /System/deviceinfo`, populated after camera LAN (`eth0`) setup and ping reachability, for Settings display and WebSocket `deviceInfo.cameraVersion`.

## Requirements

### Requirement: Unified in-memory cache for camera app version

The app SHALL maintain a single in-memory normalized camera software version string derived from `GET /System/deviceinfo` field `appVersion`. All features that need camera version for display or remote payloads SHALL read this cache via one accessor (e.g. `CameraDeviceInfoCache.getDisplay()`), not perform independent HTTP calls except through the cache’s refresh API.

Normalization SHALL match `CameraRemote.parseCameraAppVersionDisplayValue` (strip leading `v`/`V`, remove ` build…` suffix). When no successful value is cached, the accessor SHALL return exactly `-`.

After the first successful fetch stores a normalized version other than `-` for the current cache epoch, the cache module SHALL NOT issue further HTTP deviceinfo requests until the cache is explicitly invalidated (e.g. `clearAndRefresh`, successful camera network segment reconfiguration, or explicit Settings refresh that clears the epoch).

Version HTTP fetch SHALL start only when camera ping health reports reachable (`camera-ping-health-check`).

#### Scenario: Refresh after successful eth0 segment setup

- **WHEN** `setCameraNetworkSegment` successfully applies tablet `eth0` address and camera LAN route for the configured camera host
- **AND** ping health reports the camera reachable
- **THEN** the app SHALL start the unified cache backoff fetch sequence (async HTTP) targeting that host’s `GET …/System/deviceinfo`
- **AND** on HTTP 2xx with non-empty `appVersion`, the cache SHALL store the normalized string and stop further automatic HTTP retries for that epoch

#### Scenario: Refresh failure leaves placeholder

- **WHEN** the unified backoff sequence completes without a successful fetch (network error, timeout, non-2xx, empty `appVersion`)
- **THEN** the cache SHALL store or retain display value `-`
- **AND** the client SHALL NOT start periodic HTTP retries while the app process continues running

#### Scenario: Concurrent refresh coalescing

- **WHEN** multiple callers request refresh while one HTTP deviceinfo request is in flight
- **THEN** at most one HTTP deviceinfo request SHALL be active at a time for the cache module

### Requirement: Cache refresh uses fixed camera host

The unified cache HTTP refresh SHALL target `CameraConfig.getBaseCameraAppUrl()` + `System/deviceinfo` on the configured camera host from `CameraConfig.getCameraIp()` (ROM `camera_ip` when present). The client SHALL NOT read camera host from SharedPreferences or developer overrides.

#### Scenario: Default camera LAN

- **WHEN** the unified cache refresh runs after eth0 is configured for the camera segment
- **AND** the camera responds on port 9000 at the configured host
- **THEN** the client SHALL request `GET {baseUrl}System/deviceinfo` with `CameraConfig.basicAuthorization()`

### Requirement: Initial version fetch uses exponential backoff

When the cache epoch has no successful version (display is `-`) and a refresh is triggered (eth0 setup, app init with camera LAN ready, `clearAndRefresh`, or explicit Settings refresh), the client SHALL attempt HTTP `GET /System/deviceinfo` with exponential backoff delays starting at **1 second** and doubling each failed attempt for a bounded number of tries (minimum **5** attempts, e.g. 1 s, 2 s, 4 s, 8 s, 16 s) before giving up for that epoch. HTTP attempts SHALL occur only while ping health reports reachable.

#### Scenario: HTTP service starts after eth0

- **WHEN** the first backoff attempt fails because the IPC HTTP service is not yet ready
- **AND** a later attempt succeeds with HTTP 2xx and non-empty `appVersion`
- **THEN** the cache SHALL store the normalized version
- **AND** no further automatic HTTP retries SHALL run until cache invalidation

#### Scenario: Backoff exhausted without success

- **WHEN** all backoff attempts fail for the current epoch
- **THEN** the cache display SHALL remain `-`
- **AND** camera communication health SHALL still be determined by ping (`camera-ping-health-check`), not by cache display

#### Scenario: Cached version skips HTTP on scheduler ticks

- **WHEN** the cache already holds a normalized version other than `-`
- **AND** no invalidation event occurred
- **THEN** periodic application timers SHALL NOT trigger HTTP deviceinfo refresh solely to re-read the version
