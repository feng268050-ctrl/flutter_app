## Why

Fast Mode and Engineer Mode currently rely on incrementally updated process parameters, which makes it hard to guarantee that outbound status messages always reflect a complete and current parameter set. A single in-memory, real-time snapshot is needed so device state reporting stays consistent and debuggable.

## What Changes

- Build and maintain a full in-memory snapshot of process parameters whenever parameters are modified in Fast Mode or Engineer Mode.
- Define snapshot update behavior so each parameter update produces an immediately usable full snapshot view.
- Extend `device.online` and `command.stat_response` payloads to include a `processParameters` field sourced from the live in-memory snapshot.
- Ensure outbound message structure remains backward-compatible except for the additive `processParameters` payload field.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `device-remote-snapshot`: Add requirements for building and maintaining a complete real-time process-parameter snapshot and exposing it in remote snapshot-related responses.
- `device-websocket-connectivity`: Add requirements that `device.online` and `command.stat_response` websocket messages include `processParameters` with the latest full snapshot.

## Impact

- Affected code: process parameter mutation paths in Fast Mode and Engineer Mode, in-memory state/snapshot store, websocket message builders/serializers.
- Affected APIs/messages: `device.online`, `command.stat_response` payload schema (additive field `processParameters`).
- Testing impact: unit/integration validation for snapshot update correctness and websocket payload completeness under repeated parameter updates.
