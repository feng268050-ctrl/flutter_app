## ADDED Requirements

### Requirement: Remote snapshot deviceInfo includes focus scale reference

The `deviceInfo` object inside the remote snapshot (`command.stat_response` `payload.data.deviceInfo` and `device.online` `payload.stat.deviceInfo`) SHALL include integer field `focusScaleRef`. The value MUST equal `DeviceModelConfig.getFocusScaleRef()` at snapshot build time.

The field MUST NOT be persisted in Room `t_device_info`; it is populated only when assembling `DeviceInfo` for Settings display and remote snapshot serialization.

#### Scenario: Stat response includes configured focus scale reference

- **WHEN** the effective focus scale reference is `-3` at snapshot build time
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.focusScaleRef` MUST equal JSON number `-3`

#### Scenario: Stat response includes default focus scale reference

- **WHEN** ROM `model.properties` has no valid `focus_scale_ref` value
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.focusScaleRef` MUST equal JSON number `0`

#### Scenario: Device online matches stat_response deviceInfo focus scale reference

- **WHEN** the device sends `device.online` with `payload.stat.deviceInfo`
- **THEN** `payload.stat.deviceInfo.focusScaleRef` MUST equal the value that would appear as `payload.data.deviceInfo.focusScaleRef` in a contemporaneous `command.stat_response` built in the same process
