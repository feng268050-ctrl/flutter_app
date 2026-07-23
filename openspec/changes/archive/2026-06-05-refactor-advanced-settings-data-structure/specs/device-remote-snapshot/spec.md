## MODIFIED Requirements

### Requirement: Remote snapshot aggregate without connection-local device object

The app SHALL expose a transport-neutral aggregate object (“remote snapshot”) representing the same device-local information previously bundled for periodic cloud push, **excluding** any nested `device` object used only to duplicate connection-local identity on the wire.

#### Scenario: Snapshot fields cover operational context

- **WHEN** the app builds a remote snapshot for export over an approved device channel
- **THEN** the aggregate MUST be structurally capable of carrying: static layout data, device base info, **common settings** (`commonSettings`), live device status, device data, and the current warning list, each as distinct properties of the aggregate
- **AND** the aggregate MUST NOT include root property `advancedSettings`

#### Scenario: Device identity field omitted from snapshot JSON

- **WHEN** the aggregate is serialized as the `data` object for `command.stat_response`
- **THEN** the serialized JSON MUST NOT include a `device` property at the root of `data`
