## ADDED Requirements

### Requirement: Outbound device online snapshot envelope

After the device WebSocket **transport has successfully opened** on the active session (per `device-websocket-connectivity`: online readiness from transport open, **not** from any inbound application message), the device SHALL send an unsolicited outbound WebSocket text frame with `type` equal to `device.online`. The frame SHALL use the unified JSON envelope with `v` equal to `1`, a newly generated top-level `id` (per outbound message identity rules), millisecond `ts`, and `payload` set to the **remote snapshot aggregate** as a JSON object.

The `payload` object SHALL have the same semantics and content rules as object `data` inside the `payload` of `command.stat_response` (see **Outbound remote snapshot response command envelope** in this capability and `device-remote-snapshot`): it SHALL represent the packed remote snapshot and SHALL NOT include a redundant root-level `device` identity object. The `payload` SHALL NOT wrap the snapshot under an extra `data` key and SHALL NOT include `request_id`.

#### Scenario: Online message uses unified envelope and snapshot payload

- **WHEN** the device sends `device.online` after the WebSocket transport opens on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload` with `type` equal to `device.online`, and `payload` MUST conform to the remote snapshot rules as used for `command.stat_response`’s `payload.data`

#### Scenario: Distinct type from stat response

- **WHEN** the device emits `device.online`
- **THEN** `type` MUST be `device.online` and MUST NOT be `command.stat_response`, and `payload` MUST NOT be shaped as `{ "request_id", "data" }` used for stat responses

#### Scenario: No prerequisite inbound message

- **WHEN** the device is about to send the first `device.online` for a new transport session
- **THEN** that send MUST NOT be conditional on having received any inbound text frame (including any legacy `connected` frame)

## REMOVED Requirements

### Requirement: Server connected payload

**Reason:** Session readiness and `device.online` are defined at **transport open**; the `connected` application message is removed from the contract and MUST NOT gate device behavior.

**Migration:** Servers MUST NOT rely on devices processing `connected` for online state. Remove emission of `connected` or upgrade clients first per rollout plan; devices ignore `connected` for lifecycle if still received during transition.
