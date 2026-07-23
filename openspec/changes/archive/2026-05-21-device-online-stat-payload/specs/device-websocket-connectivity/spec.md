## MODIFIED Requirements

### Requirement: Push remote snapshot immediately after transport open

When the WebSocket transport successfully opens for a session (including after a reconnect), the device SHALL attempt to send exactly one outbound `device.online` frame for that transport-open event, as defined in `device-ws-unified-envelope`. The attempt SHALL be scheduled **immediately** from the transport-open lifecycle point (no wait for inbound server text). The send SHALL NOT depend on a prior inbound `command.stat_request`.

#### Scenario: First open after connect

- **WHEN** the WebSocket transport opens for a newly established session
- **THEN** the device MUST attempt to emit `device.online` on that session with the current remote snapshot in `payload.stat`

#### Scenario: Reconnect obtains a new push

- **WHEN** the WebSocket transport opens again after a disconnect and a new session is established
- **THEN** the device MUST again attempt to emit `device.online` for that new transport-open event with the current remote snapshot in `payload.stat`

### Requirement: Outbound online and stat response include process-parameter snapshot

The device websocket layer SHALL include `processParameters` in outbound `device.online` (`payload.stat`) and `command.stat_response` (`payload.data`) messages. The value of `processParameters` in both message types MUST be sourced from the same live in-memory snapshot defined by `device-remote-snapshot`, and MUST represent a complete current parameter view at serialization time.

#### Scenario: device.online contains current full processParameters snapshot

- **WHEN** the device emits `device.online`
- **THEN** `payload.stat` MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: command.stat_response contains current full processParameters snapshot

- **WHEN** the device emits `command.stat_response`
- **THEN** the response payload MUST include `processParameters` equal to the latest complete in-memory process-parameter snapshot

#### Scenario: Consecutive parameter changes are reflected in later outbound messages

- **WHEN** one or more process-parameter updates are committed before the next outbound `device.online` or `command.stat_response`
- **THEN** the next emitted message MUST carry `processParameters` reflecting all committed updates up to that serialization point

### Requirement: Outbound processParameters JSON property names match ProcessParametersData

The JSON object serialized for the `processParameters` field in outbound `device.online` (`payload.stat`) and `command.stat_response` (`payload.data`) messages (sourced from the in-memory snapshot per `device-remote-snapshot`) SHALL use the same camelCase property names as the `ProcessParametersData` Gson/Room model after field rename. For the logical display name, material type code, and custom material label, the JSON properties SHALL be **`name`**, **`materialType`**, and **`materialName`**. The serialized object MUST NOT include legacy keys **`paramsName`**, **`materials`**, or **`materialsName`** for those values.

#### Scenario: device.online snapshot omits legacy keys

- **WHEN** the device emits `device.online` with a non-null `processParameters` object in `payload.stat`
- **THEN** the serialized `processParameters` object MUST NOT contain the keys `paramsName`, `materials`, or `materialsName`

#### Scenario: stat_response snapshot uses canonical keys

- **WHEN** the device emits `command.stat_response` with a non-null `processParameters` object in the payload
- **THEN** any present display name, material code, and custom material label in that object MUST appear under `name`, `materialType`, and `materialName` respectively
