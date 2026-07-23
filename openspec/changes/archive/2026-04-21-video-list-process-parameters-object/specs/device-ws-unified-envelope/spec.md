## ADDED Requirements

### Requirement: Video list list-item process parameters key

For `command.video_list_response`, each object in `payload.data.list` that carries parsed process parameters from the device store SHALL use the JSON property name **`processParameters`** (object or null) as specified in `device-ws-video-list-command`, and SHALL NOT use **`processData`** / **`process_data`** for that value on the WebSocket list payload.

#### Scenario: Cross-command naming consistency

- **WHEN** the device emits `command.video_list_response` including process parameters for a row
- **THEN** the field name in the JSON list item MUST be `processParameters`, consistent with `command.stat_response` naming for the same logical data type
