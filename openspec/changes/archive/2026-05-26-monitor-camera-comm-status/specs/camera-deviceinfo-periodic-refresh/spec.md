## ADDED Requirements

### Requirement: App-wide periodic camera deviceinfo refresh

While the main application process is running, the client SHALL invoke `CameraDeviceInfoCache.refresh(Context)` on a fixed **1 second** interval using the application `Context`. Each tick SHALL use the existing unified cache module (same HTTP URL, normalization, in-flight coalescing, and `CacheKey.CAMERA_VERSION_DISPLAY` notification) as event-driven refresh paths.

#### Scenario: Timer starts with application

- **WHEN** `LaserApplication` (or equivalent application entry) finishes initialization
- **THEN** the 1 second periodic refresh schedule SHALL be started

#### Scenario: Concurrent refresh coalescing under timer

- **WHEN** a periodic tick fires while a deviceinfo HTTP request from the cache module is already in flight
- **THEN** at most one HTTP deviceinfo request SHALL remain active
- **AND** the tick SHALL NOT start a duplicate parallel request

#### Scenario: Successful refresh updates cache

- **WHEN** periodic refresh completes with HTTP 2xx and non-empty `appVersion`
- **THEN** the unified cache SHALL store the normalized version string
- **AND** `MemoryCacheManager` SHALL notify listeners for `CAMERA_VERSION_DISPLAY`

#### Scenario: Failed refresh retains placeholder

- **WHEN** periodic refresh fails (timeout, network error, non-2xx, empty `appVersion`)
- **THEN** the cache display value SHALL be or remain `-`
