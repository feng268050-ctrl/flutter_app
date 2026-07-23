## ADDED Requirements

### Requirement: Inbound process library WebSocket command types

Inbound frames for engineer-mode process library remote management SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`) with `type` one of:

- **`command.process_library_request`**
- **`command.process_parameters_request`**
- **`command.process_parameters_create`**
- **`command.process_parameters_update`**
- **`command.process_parameters_delete`**
- **`command.process_parameters_set_default`**

Business fields SHALL reside in **`payload`** only, not at the top level.

#### Scenario: List command frame structure

- **WHEN** the server sends `command.process_library_request`
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, and MUST NOT place `process_type` outside `payload`

### Requirement: Outbound process library WebSocket response and ack types

Outbound frames for this feature SHALL use `type` one of:

- **`command.process_library_response`**
- **`command.process_parameters_response`**
- **`command.process_parameters_create_ack`**
- **`command.process_parameters_update_ack`**
- **`command.process_parameters_delete_ack`**
- **`command.process_parameters_set_default_ack`**

Response types (`*_response`) SHALL include **`request_id`** in `payload` equal to the inbound command’s top-level **`id`**, and SHALL use a **newly generated** outbound top-level **`id`**. Ack types (`*_ack`) SHALL follow the **`command.upload_video_ack`** payload shape (`request_id` + `data.success` + `data.message`).

#### Scenario: Response does not reuse inbound id

- **WHEN** the device replies to `command.process_parameters_request` whose top-level `id` is `req-p-9`
- **THEN** the outbound `command.process_parameters_response` MUST use a new top-level `id` and `payload.request_id` MUST be `req-p-9`
