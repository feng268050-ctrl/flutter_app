## ADDED Requirements

### Requirement: Unified in-memory cache for camera app version

The app SHALL maintain a single in-memory normalized camera software version string derived from `GET /System/deviceinfo` field `appVersion`. All features that need camera version for display or remote payloads SHALL read this cache via one accessor (e.g. `CameraDeviceInfoCache.getDisplay()`), not perform independent HTTP calls except through the cache’s refresh API.

Normalization SHALL match `CameraRemote.parseCameraAppVersionDisplayValue` (strip leading `v`/`V`, remove ` build…` suffix). When no successful value is cached, the accessor SHALL return exactly `-`.

#### Scenario: Refresh after successful eth0 segment setup

- **WHEN** `setCameraNetworkSegment` successfully applies tablet `eth0` address and camera LAN route for the configured camera host
- **THEN** the app SHALL invoke the unified cache refresh (async HTTP) targeting that host’s `GET …/System/deviceinfo`
- **AND** on HTTP 2xx with non-empty `appVersion`, the cache SHALL store the normalized string

#### Scenario: Refresh failure leaves placeholder

- **WHEN** the unified refresh fails (network error, timeout, non-2xx, empty `appVersion`)
- **THEN** the cache SHALL store or retain display value `-`

#### Scenario: Concurrent refresh coalescing

- **WHEN** multiple callers request refresh while one request is in flight
- **THEN** at most one HTTP deviceinfo request SHALL be active at a time for the cache module

### Requirement: Camera host change invalidates and reloads cache

- **WHEN** the operator updates the configured camera host (`CameraConfig.PREF_CAMERA_RTSP_HOST`)
- **THEN** the app SHALL clear or overwrite the prior cached camera version and SHALL schedule a unified cache refresh for the new host
