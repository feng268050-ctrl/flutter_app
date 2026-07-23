## ADDED Requirements

### Requirement: Monitor alerts SSE endpoint exists and uses standard SSE headers

The device SHALL expose a device-local HTTP endpoint **`GET /v1/monitor/alerts`**. On success, the endpoint MUST respond with HTTP **200** and:

- `Content-Type: text/event-stream; charset=utf-8`
- `Cache-Control: no-cache`

The response body MUST use valid Server-Sent Events framing (`event:` / `data:` lines, blank line between events).

#### Scenario: Successful SSE connection

- **WHEN** a client opens `GET /v1/monitor/alerts` and the monitor alerts publisher starts successfully
- **THEN** the HTTP status MUST be 200
- **AND** `Content-Type` MUST be `text/event-stream; charset=utf-8`
- **AND** the body MUST deliver valid SSE frames

### Requirement: Initial list event on connect

When a client connects to `GET /v1/monitor/alerts`, the device SHALL load the current warn list using the same logic as `command.stat_response` `payload.data.warns` and MUST emit **`event: list`** as the first event on that connection before any `new` or `clear` event.

The `data` line for `list` MUST be a JSON array whose elements are warn objects with the same field names and values as would appear in `warns` at that instant (including localized `content`).

#### Scenario: Client receives full current warn list

- **WHEN** a client opens `GET /v1/monitor/alerts` while the device has N persisted warn rows visible to stat
- **THEN** the first SSE event on that connection MUST be `event: list`
- **AND** parsing the `data` line MUST yield a JSON array of length N matching stat `warns` element-for-element

#### Scenario: Empty warn table

- **WHEN** a client opens `GET /v1/monitor/alerts` and no warns are visible to stat
- **THEN** the first event MUST be `event: list` with `data` equal to `[]`

### Requirement: New warn events on insert

When the device persists one or more new `WarnTable` rows (insert, not merely `newTime` update on an existing code), the alerts publisher SHALL emit **`event: new`** to all active subscribers. Each `new` event `data` line MUST be a single JSON object representing one inserted warn, with the same shape as an element of `warns` in `command.stat_response`.

#### Scenario: Subscriber receives new warn after insert

- **WHEN** a warn row is newly inserted into `warn_table` while at least one client is subscribed to `/v1/monitor/alerts`
- **THEN** each subscriber MUST receive at least one `event: new` whose `data` object includes that row's `code` and localized `content`

#### Scenario: Duplicate code refresh does not emit new

- **WHEN** an incoming alarm only updates `newTime` on an existing `code` within the dedupe window
- **THEN** the device MUST NOT emit `event: new` for that update

### Requirement: Clear event on wipe

When all persisted warns are cleared (on-device UI clear or successful remote `command.clear_alerts`), the alerts publisher SHALL emit **`event: clear`** to all active subscribers. The `data` line MUST be the JSON object `{}`.

#### Scenario: Clear after remote command

- **WHEN** `command.clear_alerts` completes successfully and subscribers are connected
- **THEN** each subscriber MUST receive `event: clear` with `data` `{}`

#### Scenario: Clear after local UI

- **WHEN** the operator clears the warn log from the HMI and subscribers are connected
- **THEN** each subscriber MUST receive `event: clear` with `data` `{}`

### Requirement: Heartbeat events keep the stream alive

While the connection remains open, the endpoint SHALL emit `event: heartbeat` at least every **15 seconds** with JSON `data` of `{}` or `{"ok":true}`.

#### Scenario: Idle connection receives heartbeat

- **WHEN** a client remains connected to `/v1/monitor/alerts` for 20 seconds
- **AND** no `list`, `new`, or `clear` events are emitted in that interval
- **THEN** the client MUST receive at least one `heartbeat` event in that interval

### Requirement: Fan-out without per-subscriber DB polling

The device SHALL maintain at most one warn-change listener for `/v1/monitor/alerts` regardless of subscriber count. Each `list`, `new`, or `clear` event produced SHALL be written to all active subscribers.

#### Scenario: Two subscribers observe the same alert stream

- **WHEN** two clients connect concurrently to `GET /v1/monitor/alerts`
- **THEN** both clients MUST receive the same sequence of `new` and `clear` events (ordering preserved per emission)
- **AND** each client MUST receive its own initial `list` on connect
