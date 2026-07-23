## REMOVED Requirements

### Requirement: App-wide periodic camera deviceinfo refresh

**Reason:** Periodic HTTP `GET /System/deviceinfo` every second imposes unnecessary load on the IPC and is replaced by ICMP ping for connectivity (`camera-ping-health-check`). Version fetch is handled by fetch-once-with-backoff in `camera-version-deviceinfo-cache`.

**Migration:** Remove HTTP calls from `CameraDeviceInfoRefreshScheduler` (or its replacement). Start `CameraPingHealthScheduler` at application init instead. Update tests that asserted 1 Hz HTTP refresh.

## ADDED Requirements

### Requirement: App-wide periodic camera ping health probe

While the main application process is running, the client SHALL invoke the unified camera ping health probe on a fixed **1 second** interval using the application `Context`. Each tick SHALL update the process-wide reachability flag used by `CameraCommStatus` and SHALL NOT invoke `CameraDeviceInfoCache.refresh()` or any HTTP deviceinfo request.

#### Scenario: Timer starts with application

- **WHEN** `LaserApplication` (or equivalent application entry) finishes initialization
- **THEN** the 1 second periodic ping schedule SHALL be started

#### Scenario: Timer does not poll deviceinfo

- **WHEN** a periodic tick fires
- **THEN** the client SHALL NOT start an HTTP request to `System/deviceinfo` as part of that tick

#### Scenario: Concurrent ping coalescing under timer

- **WHEN** a periodic tick fires while a ping probe is already in flight
- **THEN** at most one ping process SHALL remain active
- **AND** the tick SHALL NOT start a duplicate parallel ping
