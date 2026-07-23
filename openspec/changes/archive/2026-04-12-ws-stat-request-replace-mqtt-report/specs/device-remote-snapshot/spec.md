## ADDED Requirements

### Requirement: Remote snapshot aggregate without connection-local device object

The app SHALL expose a transport-neutral aggregate object (“remote snapshot”) representing the same device-local information previously bundled for periodic cloud push, **excluding** any nested `device` object used only to duplicate connection-local identity on the wire.

#### Scenario: Snapshot fields cover operational context

- **WHEN** the app builds a remote snapshot for export over an approved device channel
- **THEN** the aggregate MUST be structurally capable of carrying the same categories of information as the pre-change packed aggregate: static layout data, device base info, advanced settings, live device status, device data, and the current warning list, each as distinct properties of the aggregate

#### Scenario: Device identity field omitted from snapshot JSON

- **WHEN** the aggregate is serialized as the `data` object for `command.stat_response`
- **THEN** the serialized JSON MUST NOT include a `device` property at the root of `data`

### Requirement: Naming independence from legacy MQTT message types

Types, packages, and public identifiers introduced or repurposed solely for this remote snapshot and its WebSocket serialization SHALL NOT include the substrings `MQTT`, `Mq`, or `MQ` in their names.

#### Scenario: DTO and builder naming

- **WHEN** new or refactored Java types are added to represent the snapshot for WebSocket export
- **THEN** their simple names MUST NOT contain `MQTT`, `Mq`, or `MQ`, and methods that only fill UI version from the installed APK MUST NOT be named with an `Mqtt` suffix
