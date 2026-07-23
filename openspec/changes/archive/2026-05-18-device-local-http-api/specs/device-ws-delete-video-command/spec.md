## ADDED Requirements

### Requirement: Inbound delete video command

The system SHALL handle inbound WebSocket frames with `type` **`command.delete_video`**. The `payload` object SHALL be present and SHALL include string field **`video_id`** identifying the business video UUID to delete. The system SHALL use the same delete semantics as **`DELETE /v1/videos/:video_id`** on the local HTTP API (remove local file when present, then remove the database row).

#### Scenario: Valid delete command

- **WHEN** the server sends `command.delete_video` with top-level `id` `req-del-1` and `payload.video_id` equal to an existing `videoId`
- **THEN** the device MUST delete the row and local file per HTTP delete rules

#### Scenario: Missing video_id

- **WHEN** `command.delete_video` arrives without a non-empty `video_id`
- **THEN** the device MUST NOT delete arbitrary rows and MUST still send `command.delete_video_ack` indicating failure

### Requirement: Outbound delete video acknowledgment

After processing `command.delete_video`, the device SHALL send a WebSocket frame with `type` **`command.delete_video_ack`**. The outbound frame SHALL use the unified envelope with a **new** top-level `id`, millisecond `ts`, and `payload` with the **same shape as `command.upload_video_ack`**:

- string **`request_id`** equal to the inbound frame’s top-level `id`
- object **`data`** containing:
  - boolean **`success`**
  - string **`message`** (human-readable result; empty string allowed on success)

#### Scenario: Ack correlates to inbound id

- **WHEN** the device receives `command.delete_video` with top-level `id` `req-del-1`
- **THEN** the device MUST send `command.delete_video_ack` whose `payload.request_id` is `req-del-1`, whose top-level `id` is newly generated, and whose `payload.data` is present

#### Scenario: Successful delete ack

- **WHEN** delete completes for a valid `video_id`
- **THEN** `command.delete_video_ack` MUST have `payload.data.success` true

#### Scenario: Failed delete ack

- **WHEN** delete fails (for example unknown `video_id` or file delete failure)
- **THEN** `command.delete_video_ack` MUST have `payload.data.success` false and a non-empty `payload.data.message` describing the failure

### Requirement: Off-main-thread delete handling

The system SHALL perform file and database deletion for `command.delete_video` on a background executor, not on the Android main thread.

#### Scenario: Delete does not block UI

- **WHEN** `command.delete_video` is accepted
- **THEN** blocking delete work MUST run off the main thread
