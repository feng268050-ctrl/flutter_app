## ADDED Requirements

### Requirement: Extended process video list request payload fields

Inbound frames with `type` `command.video_list_request` SHALL continue to require numeric **`page`** and **`page_size`** in `payload` as today. The `payload` object MAY additionally include optional filter fields:

- **`process_type`** (numeric, optional)
- **`start_date`** (numeric, optional, epoch milliseconds)
- **`end_date`** (numeric, optional, epoch milliseconds)

These fields SHALL remain inside `payload` and MUST NOT appear at the envelope top level.

#### Scenario: Filter fields inside payload

- **WHEN** the server sends `command.video_list_request` with filters
- **THEN** `process_type`, `start_date`, and `end_date` MUST be properties of `payload`, not top-level envelope fields

### Requirement: Inbound delete video command envelope

Inbound frames with `type` equal to **`command.delete_video`** SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and SHALL include string field **`video_id`**.

#### Scenario: Delete command frame structure

- **WHEN** the server sends `command.delete_video`
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload` with `type` equal to `command.delete_video`, and MUST NOT place `video_id` outside `payload`

### Requirement: Outbound delete video acknowledgment envelope

After the device completes handling `command.delete_video`, the device SHALL send a WebSocket frame with `type` **`command.delete_video_ack`**. The outbound frame SHALL use the unified envelope with `v` equal to `1`, a newly generated top-level `id`, millisecond `ts`, and `payload` containing **`request_id`** (inbound top-level `id`) and object **`data`** with boolean **`success`** and string **`message`**, matching **`command.upload_video_ack`**.

#### Scenario: Delete ack uses new outbound id

- **WHEN** the device receives `command.delete_video` with top-level `id` `req-del-1`
- **THEN** the device MUST send `command.delete_video_ack` with a new top-level `id`, `payload.request_id` equal to `req-del-1`, and `payload.data` with `success` and `message`
