## REMOVED Requirements

### Requirement: Periodic refresh while application is running

**Reason:** Version is fetched once per cache epoch with exponential backoff; ongoing 1 Hz HTTP refresh is removed to reduce IPC load.

**Migration:** Delete periodic `CameraDeviceInfoCache.refresh` from application scheduler. Retain event-driven refresh triggers documented in ADDED requirements below.

## MODIFIED Requirements

### Requirement: Unified in-memory cache for camera app version

The app SHALL maintain a single in-memory normalized camera software version string derived from `GET /System/deviceinfo` field `appVersion`. All features that need camera version for display or remote payloads SHALL read this cache via one accessor (e.g. `CameraDeviceInfoCache.getDisplay()`), not perform independent HTTP calls except through the cache’s refresh API.

Normalization SHALL match `CameraRemote.parseCameraAppVersionDisplayValue` (strip leading `v`/`V`, remove ` build…` suffix). When no successful value is cached, the accessor SHALL return exactly `-`.

After the first successful fetch stores a normalized version other than `-` for the current cache epoch, the cache module SHALL NOT issue further HTTP deviceinfo requests until the cache is explicitly invalidated (e.g. `clearAndRefresh`, successful camera network segment reconfiguration, or explicit Settings refresh that clears the epoch).

#### Scenario: Refresh after successful eth0 segment setup

- **WHEN** `setCameraNetworkSegment` successfully applies tablet `eth0` address and camera LAN route for the configured camera host
- **THEN** the app SHALL start the unified cache backoff fetch sequence (async HTTP) targeting that host’s `GET …/System/deviceinfo`
- **AND** on HTTP 2xx with non-empty `appVersion`, the cache SHALL store the normalized string and stop further automatic HTTP retries for that epoch

#### Scenario: Refresh failure leaves placeholder

- **WHEN** the unified backoff sequence completes without a successful fetch (network error, timeout, non-2xx, empty `appVersion`)
- **THEN** the cache SHALL store or retain display value `-`
- **AND** the client SHALL NOT start periodic HTTP retries while the app process continues running

#### Scenario: Concurrent refresh coalescing

- **WHEN** multiple callers request refresh while one HTTP deviceinfo request is in flight
- **THEN** at most one HTTP deviceinfo request SHALL be active at a time for the cache module

## ADDED Requirements

### Requirement: Initial version fetch uses exponential backoff

When the cache epoch has no successful version (display is `-`) and a refresh is triggered (eth0 setup, app init with camera LAN ready, `clearAndRefresh`, or explicit Settings refresh), the client SHALL attempt HTTP `GET /System/deviceinfo` with exponential backoff delays starting at **1 second** and doubling each failed attempt for a bounded number of tries (minimum **5** attempts, e.g. 1 s, 2 s, 4 s, 8 s, 16 s) before giving up for that epoch.

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
