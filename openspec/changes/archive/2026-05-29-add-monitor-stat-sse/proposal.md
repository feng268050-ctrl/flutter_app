## Why

Remote operators and companion clients (e.g. a phone app on the same LAN) need a low-latency “Monitor” view comparable to the on-device HMI Monitor screen. Today, the most complete snapshot is `command.stat_response` over the cloud WebSocket, but LAN clients have no equivalent streaming channel and must poll multiple sources (or rely on cloud availability), resulting in higher latency and more integration effort.

## What Changes

- Add **LAN local HTTP** endpoint `**GET /v1/monitor/stat`** that responds as **Server-Sent Events (SSE)** (`text/event-stream`).
- Each SSE message carries **only** the two sub-objects already present in `command.stat_response` remote snapshot:
  - `deviceStatus`
  - `deviceData`
- `deviceStatus` is extended to include `cameraStatus` (0/1) so camera communication health is available to both `command.stat_response` and LAN monitor consumers from the same snapshot object.
- The device samples `deviceStatus` and `deviceData` every **100ms**, compares with the previous sample, and **only pushes** to the SSE stream when a change is detected.
- Provide a **field-to-meaning mapping document** derived from current HMI Monitor usage so external clients can implement a compatible monitor UI.

## Capabilities

### New Capabilities

- `device-local-http-monitor-stat-sse`: Provide `GET /v1/monitor/stat` SSE stream of `{ deviceStatus, deviceData }` derived from the same in-process sources as `command.stat_response`, with 100ms sampling and change-only emission semantics.

### Modified Capabilities

- (none)

## Impact

- **API surface**: New LAN endpoint on `DeviceLocalHttpServer` under `/v1/monitor/stat` using SSE framing and long-lived connections.
- **Runtime/perf**: Adds a 100ms sampling loop per active subscriber set (fan-out), plus lightweight equality checking and serialization; must avoid heavy allocations and ensure safe cleanup on disconnect.
- **Docs**: Add/extend documentation describing the endpoint and the mapping between `deviceStatus`/`deviceData` fields and the Monitor UI meaning, for external client implementers.
