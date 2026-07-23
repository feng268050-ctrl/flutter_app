## ADDED Requirements

### Requirement: Remote snapshot includes lock flag

The remote snapshot aggregate serialized as `command.stat_response` `payload.data` and as `device.online` `payload` SHALL include a boolean JSON field `isLocked` at the root of the snapshot object. The value MUST reflect the current persisted remote lock flag from `device-remote-lock` at serialization time.

#### Scenario: Stat response reports locked device

- **WHEN** the remote lock flag is true and the device sends `command.stat_response`
- **THEN** `payload.data.isLocked` MUST be JSON `true`

#### Scenario: Stat response reports unlocked device

- **WHEN** the remote lock flag is false and the device sends `command.stat_response`
- **THEN** `payload.data.isLocked` MUST be JSON `false`

#### Scenario: Device online matches stat_response lock field

- **WHEN** the device sends `device.online` with a remote snapshot payload
- **THEN** `payload.isLocked` MUST equal the value that would appear as `payload.data.isLocked` in a contemporaneous `command.stat_response`
