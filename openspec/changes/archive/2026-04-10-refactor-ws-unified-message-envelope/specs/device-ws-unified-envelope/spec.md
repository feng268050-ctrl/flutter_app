## ADDED Requirements

### Requirement: Unified JSON envelope for all WebSocket text frames
All device WebSocket JSON text frames sent or received by the device SHALL be a single JSON object with exactly these top-level fields: `v` (number), `type` (string), `id` (string), `ts` (number), `payload` (object). The `payload` object SHALL be present for every frame; when no type-specific data is needed, it SHALL be the empty object `{}`.

#### Scenario: Outbound frame structure
- **WHEN** the device sends any JSON text frame on the device WebSocket
- **THEN** the serialized JSON MUST include `v`, `type`, `id`, `ts`, and `payload`, and MUST NOT place type-specific business fields outside `payload`

#### Scenario: Inbound frame structure
- **WHEN** the device receives a JSON text frame on the device WebSocket
- **THEN** the transport layer MUST parse `v`, `type`, `id`, `ts`, and `payload` before dispatching by `type`; frames missing any of these top-level fields or with non-object `payload` MUST be treated as protocol errors per implementation policy (drop and log, or close—documented in implementation)

### Requirement: Protocol version field
The device SHALL set `v` to the integer `1` for all frames until a future specification defines a higher version. The device SHALL reject or safely ignore inbound frames with unsupported `v` values according to implementation policy without transitioning to online state based on such frames.

#### Scenario: Supported version on connect handshake completion
- **WHEN** an inbound frame declares `v` equal to `1`
- **THEN** the device MAY process it according to `type` and `payload` rules

### Requirement: Message identity and timestamp fields
The device SHALL generate a unique string `id` for every outbound frame it originates. The device SHALL set `ts` to the Unix epoch time in milliseconds at send time for outbound frames. For inbound frames, the device SHOULD preserve server-provided `id` and `ts` for logging and correlation without requiring them to be unique across sessions.

#### Scenario: Outbound heartbeat identifiers
- **WHEN** the device sends a `heartbeat` frame
- **THEN** `id` MUST be non-empty and `ts` MUST be a positive millisecond timestamp

### Requirement: Device-originated heartbeat payload
Frames with `type` equal to `heartbeat` SHALL have `payload` equal to the empty object `{}`.

#### Scenario: Heartbeat emission shape
- **WHEN** the device emits a keepalive heartbeat on the WebSocket
- **THEN** `type` MUST be `heartbeat` and `payload` MUST serialize as `{}`

### Requirement: Server heartbeat acknowledgement payload
Frames with `type` equal to `heartbeat_ack` SHALL have `payload` equal to the empty object `{}`.

#### Scenario: Heartbeat acknowledgement handling shape
- **WHEN** the server responds to a device heartbeat
- **THEN** the inbound frame MUST have `type` `heartbeat_ack` and `payload` equal to `{}`

### Requirement: Server connected payload
Frames with `type` equal to `connected` SHALL include a `payload` object that contains string field `sn` and string field `connection_id`. Both fields SHALL be non-empty for a frame to qualify as the online-confirming `connected` message.

#### Scenario: Connected payload fields present
- **WHEN** the server sends the session `connected` frame
- **THEN** `payload.sn` and `payload.connection_id` MUST be present, non-empty strings, and the frame MUST use the unified envelope with `v` equal to `1`
