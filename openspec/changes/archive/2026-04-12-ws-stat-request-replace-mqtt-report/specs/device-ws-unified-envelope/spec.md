## ADDED Requirements

### Requirement: Inbound remote snapshot request command envelope

Inbound frames with `type` equal to `command.stat_request` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present; when the server has no additional parameters, `payload` MAY be the empty object `{}`.

#### Scenario: Request frame structure

- **WHEN** the server sends a `command.stat_request` message on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.stat_request`, and MUST NOT place request parameters outside `payload`

### Requirement: Outbound remote snapshot response command envelope

After the device completes building the remote snapshot for a given `command.stat_request`, the device SHALL send a WebSocket frame with `type` `command.stat_response`. The outbound frame SHALL use the unified envelope with `v` equal to `1`, a newly generated top-level `id` (per outbound message identity rules), millisecond `ts`, and `payload` as a JSON object containing:

- string field `request_id` whose value equals the top-level `id` of the inbound `command.stat_request` frame
- object field `data` whose value is the remote snapshot aggregate (per `device-remote-snapshot` capability), serialized as a JSON object

#### Scenario: Response uses new outbound id

- **WHEN** the device receives `command.stat_request` with top-level `id` `server-stat-1`
- **THEN** the device MUST send `command.stat_response` whose top-level `id` is newly generated for that response and MUST NOT reuse `server-stat-1` as the outbound top-level `id`

#### Scenario: Response payload carries correlation and data

- **WHEN** the device sends `command.stat_response` in response to an inbound `command.stat_request` whose top-level `id` is `server-stat-1`
- **THEN** `payload` MUST include `request_id` equal to `server-stat-1` and MUST include object `data` conforming to the remote snapshot rules without a root-level `device` property
