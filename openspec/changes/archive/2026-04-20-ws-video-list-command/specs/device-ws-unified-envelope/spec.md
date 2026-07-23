### Requirement: Inbound process video list request command envelope

Inbound frames with `type` equal to `command.video_list_request` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and SHALL include:

- numeric field `page` (1-based page index)
- numeric field `page_size` (page size)

#### Scenario: Request frame structure

- **WHEN** the server sends a `command.video_list_request` message on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.video_list_request`, and MUST NOT place `page` or `page_size` outside `payload`

### Requirement: Outbound process video list response command envelope

After the device completes handling a given `command.video_list_request`, the device SHALL send a WebSocket frame with `type` `command.video_list_response`. The outbound frame SHALL use the unified envelope with `v` equal to `1`, a **newly generated** top-level `id` (per outbound message identity rules), millisecond `ts`, and `payload` as a JSON object containing:

- string field `request_id` whose value equals the top-level `id` of the inbound `command.video_list_request` frame
- object field `data` containing:
  - array field `list` whose elements are JSON objects representing process video rows per `device-ws-video-list-command`
  - numeric field `total` whose value is the total count of rows matching the `syncStatus != 0` filter (not just the current page length)

#### Scenario: Response uses new outbound id

- **WHEN** the device receives `command.video_list_request` with top-level `id` `server-video-1`
- **THEN** the device MUST send `command.video_list_response` whose top-level `id` is newly generated for that response and MUST NOT reuse `server-video-1` as the outbound top-level `id`

#### Scenario: Response payload carries correlation and paged data

- **WHEN** the device sends `command.video_list_response` in response to an inbound `command.video_list_request` whose top-level `id` is `server-video-1`
- **THEN** `payload` MUST include `request_id` equal to `server-video-1`, MUST include array `data.list`, and MUST include numeric `data.total`
