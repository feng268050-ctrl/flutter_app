## ADDED Requirements

### Requirement: Monitor stat SSE endpoint exists and uses standard SSE headers

The device SHALL expose a device-local HTTP endpoint **`GET /v1/monitor/stat`**. On success, the endpoint MUST respond with HTTP **200** and:

- `Content-Type: text/event-stream; charset=utf-8`
- `Cache-Control: no-cache`

The response body MUST use valid [Server-Sent Events] framing (`event:` / `data:` lines, blank line between events).

#### Scenario: Successful SSE connection

- **WHEN** a client opens `GET /v1/monitor/stat` and the monitor stat publisher starts successfully
- **THEN** the HTTP status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the body MUST deliver valid SSE frames

### Requirement: Immediate stat on subscriber connect

When a client connects to `GET /v1/monitor/stat`, the device SHALL immediately sample the latest available `deviceStatus`, `deviceData`, and `processParameters` and MUST emit one `event: stat` message to that subscriber before waiting for the next 100ms sampling tick or a value change.

#### Scenario: New subscriber receives current snapshot on connect

- **WHEN** a client opens `GET /v1/monitor/stat` and the monitor stat publisher starts successfully
- **AND** cached monitor values are available
- **THEN** the client MUST receive a `stat` event reflecting the current snapshot without waiting for a subsequent change

### Requirement: Change-only stat events sampled at 100ms

While at least one subscriber is connected, the device SHALL sample the latest available `deviceStatus`, `deviceData`, and `processParameters` values at a cadence of **100ms**. After the initial connect emission, the device SHALL compare each sampled set against the last emitted set, and it MUST emit a new SSE message only when at least one of `deviceStatus`, `deviceData`, or `processParameters` has changed.

#### Scenario: No emission when unchanged

- **WHEN** the device has an active `/v1/monitor/stat` subscriber
- **AND** `deviceStatus` and `deviceData` samples remain unchanged for 1 second
- **THEN** the device MUST NOT emit any `event: stat` messages during that interval

#### Scenario: Emit stat when changed

- **WHEN** the device has an active `/v1/monitor/stat` subscriber
- **AND** either `deviceStatus` or `deviceData` changes between two consecutive 100ms samples
- **THEN** the device MUST emit at least one `event: stat` message reflecting the updated values

### Requirement: Stat event payload schema

Each change event MUST be emitted as `event: stat` whose `data` line is a single JSON object with exactly these top-level fields:

- `deviceStatus`: JSON object or `null`
- `deviceData`: JSON object or `null`
- `processParameters`: JSON object or `null`

The JSON shape of `deviceStatus`, `deviceData`, and `processParameters` MUST match the corresponding objects as they appear in the remote snapshot used by WebSocket `command.stat_response` (`payload.data.deviceStatus`, `payload.data.deviceData`, and `payload.data.processParameters`) produced by the same app version.

#### Scenario: Client can parse one stat event

- **WHEN** the device emits a `stat` event
- **THEN** the SSE frame MUST include `event: stat`
- **AND** the `data` line MUST be a single JSON object containing `deviceStatus`, `deviceData`, and `processParameters` keys

### Requirement: deviceStatus includes cameraStatus (0/1)

When `deviceStatus` is non-null in a `stat` event, the `deviceStatus` object MUST include integer field `cameraStatus` whose value is:

- `1` when camera communication is healthy
- `0` when camera communication is faulted

The value MUST be sourced from the same in-process camera communication health signal that drives the HMI camera comm indicator, and it MUST be the same value that would appear at `command.stat_response` `payload.data.deviceStatus.cameraStatus` at a contemporaneous serialization instant.

#### Scenario: Healthy camera reports cameraStatus=1

- **WHEN** the camera communication health signal is healthy
- **AND** the device emits a `stat` event with non-null `deviceStatus`
- **THEN** `deviceStatus.cameraStatus` MUST equal `1`

#### Scenario: Faulted camera reports cameraStatus=0

- **WHEN** the camera communication health signal is faulted
- **AND** the device emits a `stat` event with non-null `deviceStatus`
- **THEN** `deviceStatus.cameraStatus` MUST equal `0`

### Requirement: Heartbeat events keep the stream alive

While the connection remains open, the endpoint SHALL emit `event: heartbeat` at least every **15 seconds** with JSON `data` of `{}` or `{"ok":true}`.

#### Scenario: Idle connection receives heartbeat

- **WHEN** a client remains connected to `/v1/monitor/stat` for 20 seconds
- **AND** no `stat` events are emitted in that interval
- **THEN** the client MUST receive at least one `heartbeat` event in that interval

### Requirement: Fan-out does not duplicate sampling per subscriber

The device SHALL run at most one sampling loop per process for `/v1/monitor/stat` regardless of the number of connected subscribers. Each `stat` event that is produced SHALL be written to all active subscribers.

#### Scenario: Two subscribers observe the same stat stream

- **WHEN** two clients connect concurrently to `GET /v1/monitor/stat`
- **THEN** both clients MUST receive the same sequence of `stat` events (ordering preserved per emission)
- **AND** the device MUST NOT start two independent sampling loops solely due to having two subscribers
