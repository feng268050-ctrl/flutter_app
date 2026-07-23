## Why

Remote operators and automation need a WebSocket-driven way to page through **process video** rows that are already meaningful for sync (metadata uploaded or beyond), without pulling uninitialized rows (`syncStatus == 0`). Today there is no documented `command.*` pair for listing these videos over the device WebSocket.

## What Changes

- Add handling for inbound WebSocket frames with `type` `command.video_list_request` whose `payload` includes `page` and `page_size`.
- Query `t_params_process_video` / `ProcessParamsVideo` with **pagination** and a filter **`syncStatus != 0`**, returning both the page of rows and a **total** count matching that filter.
- Respond with an outbound frame `type` `command.video_list_response` whose `payload` includes `request_id` (the inbound frame’s top-level `id`) and `data` with `list` and `total`.
- Document the new message types in the unified WebSocket envelope capability and capture list semantics in a focused capability.

## Capabilities

### New Capabilities

- `device-ws-video-list-command`: WebSocket request/response handling, pagination parameters, DB filter `syncStatus != 0`, stable list item shape for `data.list`, and total count semantics.

### Modified Capabilities

- `device-ws-unified-envelope`: Add normative envelope and payload rules for `command.video_list_request` (inbound) and `command.video_list_response` (outbound), including correlation via `request_id` equal to the inbound frame’s top-level `id`, consistent with other `command.*` / `command.*_ack` patterns already specified.

## Impact

- Device WebSocket inbound dispatcher / command routing (where other `command.*` types are handled).
- `ProcessProcessVideoDao` (or equivalent Room DAO) for **count** and **offset/limit** queries with `syncStatus != 0`.
- Serialization of list rows for the response payload (fields aligned with what consumers need; at minimum identifiers and metadata fields already on `ProcessParamsVideo` / VO patterns used elsewhere).
- Specification updates under `openspec/specs/device-ws-unified-envelope` after the change is applied (delta in this change directory during proposal phase).
