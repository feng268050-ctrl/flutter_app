## ADDED Requirements

### Requirement: Inbound server forced disconnect command envelope

Inbound frames with `type` equal to `command.disconnect` SHALL use the unified WebSocket JSON envelope (`v`, `type`, `id`, `ts`, `payload`). The `payload` object SHALL be present. When the server supplies a human-readable explanation, it SHALL be carried in `payload` as string field `reason`. When `reason` is missing, null, or not a string, the device SHALL treat the display reason as an empty string for UI interpolation only (no transport-level failure).

#### Scenario: Command frame structure

- **WHEN** the server sends a `command.disconnect` message on the device WebSocket
- **THEN** the frame MUST include top-level `v`, `type`, `id`, `ts`, and object `payload`, with `type` equal to `command.disconnect`, and MUST NOT place `reason` outside `payload`

#### Scenario: Reason string is read from payload

- **WHEN** the `payload` object contains string field `reason` with value `policy_violation`
- **THEN** the forced-disconnect UI flow MUST use `policy_violation` as the `{reason}` interpolation value
