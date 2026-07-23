## ADDED Requirements

### Requirement: Outbound processParameters JSON property names match ProcessParametersData

The JSON object serialized for the `processParameters` field in outbound `device.online` and `command.stat_response` messages (sourced from the in-memory snapshot per `device-remote-snapshot`) SHALL use the same camelCase property names as the `ProcessParametersData` Gson/Room model after field rename. For the logical display name, material type code, and custom material label, the JSON properties SHALL be **`name`**, **`materialType`**, and **`materialName`**. The serialized object MUST NOT include legacy keys **`paramsName`**, **`materials`**, or **`materialsName`** for those values.

#### Scenario: device.online snapshot omits legacy keys

- **WHEN** the device emits `device.online` with a non-null `processParameters` object in the payload
- **THEN** the serialized `processParameters` object MUST NOT contain the keys `paramsName`, `materials`, or `materialsName`

#### Scenario: stat_response snapshot uses canonical keys

- **WHEN** the device emits `command.stat_response` with a non-null `processParameters` object in the payload
- **THEN** any present display name, material code, and custom material label in that object MUST appear under `name`, `materialType`, and `materialName` respectively
