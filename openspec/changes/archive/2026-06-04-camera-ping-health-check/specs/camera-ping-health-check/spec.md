## ADDED Requirements

### Requirement: Periodic ICMP ping to configured camera IP

While the main application process is running, the client SHALL probe camera reachability by executing a single ICMP ping to `CameraConfig.getCameraIp()` on a fixed **1 second** interval. Each probe SHALL run off the main thread, coalesce concurrent probes (at most one ping in flight), and update a process-wide reachable flag consumed by `CameraCommStatus`.

#### Scenario: Scheduler starts with application

- **WHEN** `LaserApplication` (or equivalent application entry) finishes initialization
- **THEN** the 1 second periodic ping schedule SHALL be started

#### Scenario: Successful ping marks camera reachable

- **WHEN** a ping probe completes with shell exit code 0 for the configured camera IP
- **THEN** `CameraCommStatus.isHealthy()` SHALL return true
- **AND** `CameraCommStatus.isFault()` SHALL return false

#### Scenario: Failed ping marks camera unreachable

- **WHEN** a ping probe completes with non-zero exit code, times out, or cannot be executed
- **THEN** `CameraCommStatus.isFault()` SHALL return true
- **AND** `CameraCommStatus.isHealthy()` SHALL return false

#### Scenario: Concurrent probe coalescing

- **WHEN** a periodic tick fires while a ping probe is already in flight
- **THEN** at most one ping process SHALL remain active
- **AND** the tick SHALL NOT start a duplicate parallel ping

#### Scenario: On-demand blocking probe

- **WHEN** `CameraUtils.checkCameraBlocking()` or equivalent connectivity gate runs
- **THEN** the client SHALL evaluate reachability using the ping health module (awaiting the latest probe or triggering one) with a bounded timeout
- **AND** the gate MUST NOT invoke `GET /System/deviceinfo` solely to determine connectivity
