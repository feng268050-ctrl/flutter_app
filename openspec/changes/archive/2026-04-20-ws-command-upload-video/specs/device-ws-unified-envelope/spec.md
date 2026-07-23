## ADDED Requirements

### Requirement: Inbound command.upload_video envelope

Inbound frames with `type` equal to `command.upload_video` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and SHALL include string field `videoId` (non-empty when the command is well-formed). The device SHALL NOT interpret business fields outside `payload`.

#### Scenario: Command frame structure

- **WHEN** the server sends a `command.upload_video` message on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.upload_video`, and MUST NOT place `videoId` outside `payload`

### Requirement: Outbound command.upload_video_ack envelope

After the device finishes handling a given `command.upload_video` (success or failure at command level), the device SHALL send a WebSocket frame with `type` `command.upload_video_ack`. The outbound frame SHALL use the unified envelope with `v` equal to `1`, a **newly generated** top-level `id` (per outbound message identity rules), millisecond `ts`, and `payload` as a JSON object containing:

- string field `request_id` whose value equals the top-level `id` of the inbound `command.upload_video` frame
- object field `data` with boolean field `success` and string field `message`

#### Scenario: Ack uses new message id

- **WHEN** the device receives `command.upload_video` with top-level `id` `server-upload-1`
- **THEN** the device MUST send `command.upload_video_ack` whose top-level `id` is newly generated for that ack and MUST NOT reuse `server-upload-1` as the outbound top-level `id`

#### Scenario: Ack payload carries correlation and result

- **WHEN** the device sends `command.upload_video_ack` in response to an inbound `command.upload_video` whose top-level `id` is `server-upload-1`
- **THEN** `payload` MUST include `request_id` equal to `server-upload-1`, MUST include object `data` with `success` and `message`
