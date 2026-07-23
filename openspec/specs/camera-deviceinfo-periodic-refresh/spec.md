## Purpose

Probe camera reachability via ICMP ping on a 1 Hz schedule for Monitor, alarms, and WebSocket consumers; version fetch is handled separately by `camera-version-deviceinfo-cache`.
## Requirements
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

