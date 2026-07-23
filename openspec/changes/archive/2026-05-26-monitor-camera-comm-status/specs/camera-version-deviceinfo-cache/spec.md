## ADDED Requirements

### Requirement: Periodic refresh while application is running

In addition to refresh on successful camera LAN (`eth0`) setup, camera host change, and explicit Settings refresh, the unified cache SHALL be refreshed approximately every **1 second** for the lifetime of the main application process via `CameraDeviceInfoCache.refresh(Context)` scheduled from application startup.

#### Scenario: Application running refresh cadence

- **WHEN** the main app process is running after `LaserApplication` initialization
- **THEN** the cache module SHALL receive a refresh request at least once per second on average
- **AND** all consumers (Settings Camera Version, Monitor tiles, WebSocket `deviceInfo.cameraVersion`) SHALL observe updated values through `getDisplay()` and `CAMERA_VERSION_DISPLAY` cache notifications without issuing independent HTTP calls
