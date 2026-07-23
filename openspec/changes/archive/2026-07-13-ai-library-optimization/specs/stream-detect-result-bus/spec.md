## ADDED Requirements

### Requirement: StreamDetectResultBus SHALL parse combined frame JSON

`StreamDetectResultBus` MUST accept combined frame events from native containing `frame_pts_ms` and a `modules` object. It MUST parse each module entry and dispatch to existing per-module subscribers without requiring separate native JNI invocations per module.

#### Scenario: Combined event fans out to per-module listeners

- **WHEN** native publishes one combined JSON with `modules.lens_det` and `modules.zero_point`
- **THEN** `StreamDetectResultBus` MUST invoke lens_det subscribers with the lens_det payload
- **AND** MUST invoke zero_point subscribers with the zero_point payload
- **AND** MUST perform dispatch off the native callback thread per existing executor rules

#### Scenario: Coordinator API unchanged after combined callback

- **WHEN** `OpencvStainDetectCoordinator` subscribes via existing registration API
- **THEN** it MUST receive stain results with the same parsed fields as before per-module callbacks
- **AND** MUST NOT require caller changes

## MODIFIED Requirements

### Requirement: Event types match pipeline contract

The bus SHALL support at minimum these event categories with structured payloads:

| Event | Key fields |
|-------|------------|
| `detect_result` | module id, `timestampMs`, `frame_id`, detection JSON / parsed result |
| `combined_frame` | `frame_pts_ms`, `modules` map of module id → detection JSON |
| `pipeline_state` | `running` / `idle` / `error`, optional reconnect reason |
| `session_start` | `sessionId`, `source`, `samplingIntervalMs`, optional dimensions |
| `session_stop` | `sessionId`, `reason` |
| `error` | `code`, `message` |

Per-module `detect_result` events from separate native JNI calls are deprecated; new implementations MUST prefer `combined_frame` as the primary live sample uplink.

#### Scenario: Detect result carries timestamp for overlay sync

- **WHEN** `DetectionOverlayView` subscribes to `detect_result`
- **THEN** each event MUST include `timestampMs` and/or `frame_id` for visualization tolerance (100–300 ms)

#### Scenario: Session start before first running

- **WHEN** SSE subscribers exist and the pipeline session starts
- **THEN** subscribers MUST receive `session_start` before the first `detect_result` of that epoch

#### Scenario: Combined frame provides per-module timestamps

- **WHEN** a `combined_frame` event is received
- **THEN** each module entry dispatched to subscribers MUST include `timestampMs` derived from `frame_pts_ms` or module JSON
- **AND** overlay sync tolerance rules MUST apply identically to per-module dispatch
