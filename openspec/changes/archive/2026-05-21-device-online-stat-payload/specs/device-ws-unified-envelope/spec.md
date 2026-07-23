## MODIFIED Requirements

### Requirement: Outbound device online snapshot envelope

After the device WebSocket **transport has successfully opened** on the active session (per `device-websocket-connectivity`: online readiness from transport open, **not** from any inbound application message), the device SHALL send an unsolicited outbound WebSocket text frame with `type` equal to `device.online`. The frame SHALL use the unified JSON envelope with `v` equal to `1`, a newly generated top-level `id` (per outbound message identity rules), millisecond `ts`, and `payload` as a JSON object.

The `payload` object SHALL include object field **`stat`**. Object `stat` SHALL be the remote snapshot aggregate (per `device-remote-snapshot`), serialized as a JSON object with the same semantics and content rules as object `data` inside the `payload` of `command.stat_response`. Object `stat` SHALL NOT include a redundant root-level `device` identity object, and SHALL NOT include `request_id` or a nested `data` wrapper.

The `payload` object SHALL NOT place remote snapshot fields at the root of `payload` (for example `staticData`, `isLocked`, or `wifiInfo` MUST NOT appear as siblings of `stat` on `payload`). The `payload` SHALL NOT duplicate the snapshot outside `stat`.

#### Scenario: Online message uses unified envelope and stat field

- **WHEN** the device sends `device.online` after the WebSocket transport opens on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload` with `type` equal to `device.online`
- **AND** `payload` MUST include object `stat` conforming to the remote snapshot rules as used for `command.stat_response`’s `payload.data`

#### Scenario: Stat matches contemporaneous stat response data

- **WHEN** the device sends `device.online` and could send `command.stat_response` at the same serialization instant
- **THEN** `payload.stat` MUST deep-equal `command.stat_response` `payload.data` for that instant

#### Scenario: Distinct type from stat response

- **WHEN** the device emits `device.online`
- **THEN** `type` MUST be `device.online` and MUST NOT be `command.stat_response`
- **AND** `payload` MUST NOT be shaped as `{ "request_id", "data" }` at the `payload` root

#### Scenario: No prerequisite inbound message

- **WHEN** the device is about to send the first `device.online` for a new transport session
- **THEN** that send MUST NOT be conditional on having received any inbound text frame (including any legacy `connected` frame)

#### Scenario: Unsolicited online stat has no request_id or data wrapper

- **WHEN** the device sends unsolicited `device.online` after transport open without a prior `command.stat_request` for that uplink
- **THEN** `payload.stat` MUST NOT include `request_id`
- **AND** `payload.stat` MUST NOT include a nested `data` property wrapping the snapshot
