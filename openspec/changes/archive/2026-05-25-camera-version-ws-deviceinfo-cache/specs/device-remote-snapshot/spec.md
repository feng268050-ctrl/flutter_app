## ADDED Requirements

### Requirement: Remote snapshot deviceInfo includes camera version

The `deviceInfo` object inside the remote snapshot (`command.stat_response` `payload.data.deviceInfo` and `device.online` `payload.stat.deviceInfo`) SHALL include string field `cameraVersion`. The value MUST be the normalized camera `appVersion` from the unified in-memory cache (`camera-version-deviceinfo-cache`) at snapshot build time. When the cache has no successful value, `cameraVersion` MUST be the literal string `-`.

The field MUST NOT be persisted in Room `t_device_info`; it is populated only when assembling `DeviceInfo` for serialization (same pattern as transient `systemVersion`).

#### Scenario: Stat response includes camera version when cache populated

- **WHEN** the unified cache holds normalized version `1.0.5`
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.cameraVersion` MUST equal `1.0.5`

#### Scenario: Stat response uses placeholder when cache empty

- **WHEN** the unified cache has no successful fetch yet or last fetch failed
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.cameraVersion` MUST equal `-`

#### Scenario: Device online matches stat_response deviceInfo camera version

- **WHEN** the device sends `device.online` with `payload.stat.deviceInfo`
- **THEN** `payload.stat.deviceInfo.cameraVersion` MUST equal the value that would appear as `payload.data.deviceInfo.cameraVersion` in a contemporaneous `command.stat_response` built in the same process
