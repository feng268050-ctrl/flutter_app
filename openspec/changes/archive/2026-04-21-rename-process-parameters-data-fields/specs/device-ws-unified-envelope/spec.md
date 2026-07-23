## MODIFIED Requirements

### Requirement: Inbound process parameter command envelope

Frames with `type` equal to `command.send_process_param` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL contain the process-parameter content in a shape the device can map to the same persistence model used for MQTT `ONE_PROCESS_DATA` (`ProcessParametersData` and its MQTT message wrapper fields as implemented in the app). When that content is expressed as JSON keyed to match the `ProcessParametersData` persistence model, the camelCase property names for the former `paramsName`, `materials`, and `materialsName` fields SHALL be **`name`**, **`materialType`**, and **`materialName`** respectively. Inbound payloads MUST use those property names; the app MUST NOT accept or emit legacy keys `paramsName`, `materials`, or `materialsName` for those values on this path.

#### Scenario: Command frame structure

- **WHEN** the server sends a `command.send_process_param` message
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, and MUST NOT place process-parameter fields outside `payload`

#### Scenario: Process-parameter payload uses canonical material and name keys

- **WHEN** the `payload` carries a JSON object representing one `ProcessParametersData` row with non-null display name, material code, or custom material label
- **THEN** that object MUST use JSON properties `name`, `materialType`, and `materialName` for those values and MUST NOT use `paramsName`, `materials`, or `materialsName`
