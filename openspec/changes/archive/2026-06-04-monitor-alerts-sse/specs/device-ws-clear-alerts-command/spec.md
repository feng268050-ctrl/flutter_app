## ADDED Requirements

### Requirement: Inbound clear alerts command

The system SHALL handle inbound WebSocket frames with `type` **`command.clear_alerts`**. The frame SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present and MAY be empty (`{}`). The device SHALL clear all rows in `warn_table` using the same persistence operation as the on-device warn log clear action (`WarnTableViewModel.deleteAll` semantics).

#### Scenario: Valid clear command structure

- **WHEN** the server sends `command.clear_alerts` with top-level `id` `req-clear-1` and `payload` `{}`
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload` with `type` equal to `command.clear_alerts`

#### Scenario: Clear while not online is ignored

- **WHEN** `command.clear_alerts` arrives before the device WebSocket session is considered online per existing command gating
- **THEN** the device MUST NOT clear warns and MUST NOT send `command.clear_alerts_ack`

### Requirement: Outbound clear alerts acknowledgment

After the device finishes handling `command.clear_alerts` (success or failure at command level), the device SHALL send a WebSocket frame with `type` **`command.clear_alerts_ack`**. The outbound frame SHALL use the unified envelope with a **new** top-level `id`, millisecond `ts`, and `payload` with the **same shape as `command.upload_video_ack`**:

- string **`request_id`** equal to the inbound frame's top-level `id`
- object **`data`** containing boolean **`success`** and string **`message`**

#### Scenario: Ack correlates to inbound id

- **WHEN** the device receives `command.clear_alerts` with top-level `id` `req-clear-1`
- **THEN** the device MUST send `command.clear_alerts_ack` whose `payload.request_id` is `req-clear-1`, whose top-level `id` is newly generated, and whose `payload.data` is present

#### Scenario: Successful clear ack

- **WHEN** warn table clear completes without error
- **THEN** `command.clear_alerts_ack` MUST have `payload.data.success` true

#### Scenario: Failed clear ack

- **WHEN** clear fails (for example application context unavailable)
- **THEN** `command.clear_alerts_ack` MUST have `payload.data.success` false and a non-empty `payload.data.message` describing the failure

### Requirement: Clear notifies monitor alerts SSE

Successful processing of `command.clear_alerts` SHALL trigger the same **`event: clear`** notification path used for on-device warn log clear, so active `/v1/monitor/alerts` subscribers observe the wipe.

#### Scenario: LAN subscribers cleared after WS command

- **WHEN** `command.clear_alerts` succeeds and a client is subscribed to `GET /v1/monitor/alerts`
- **THEN** that client MUST receive `event: clear` with `data` `{}`

### Requirement: Off-main-thread clear handling

The system SHALL perform database deletion for `command.clear_alerts` on a background executor, not on the Android main thread.

#### Scenario: Clear does not block UI

- **WHEN** `command.clear_alerts` is accepted
- **THEN** blocking clear work MUST run off the main thread
