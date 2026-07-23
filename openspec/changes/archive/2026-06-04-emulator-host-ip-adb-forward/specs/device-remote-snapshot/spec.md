## ADDED Requirements

### Requirement: Remote snapshot deviceInfo includes host IP

The `deviceInfo` object inside the remote snapshot (`command.stat_response` `payload.data.deviceInfo`, `device.online` `payload.stat.deviceInfo`, and cloud `GET /v1/devices/:sn/stat` `deviceInfo` when sourced from the same snapshot) SHALL include string field `hostIp`. When ROM `/system/etc/model.properties` contains non-empty `host_ip`, the value MUST equal `DeviceModelConfig.getHostIp()` at snapshot build time. When `host_ip` is absent or empty, `hostIp` MUST be the empty string.

The field MUST NOT be persisted in Room `t_device_info`; it is populated only when assembling `DeviceInfo` for serialization.

#### Scenario: Stat response includes configured host IP

- **WHEN** ROM `host_ip` is `192.168.1.42` at snapshot build time
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.hostIp` MUST equal `192.168.1.42`

#### Scenario: Stat response uses empty host IP when ROM key absent

- **WHEN** ROM `model.properties` has no `host_ip` key or an empty value
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.hostIp` MUST equal `""`

#### Scenario: Device online matches stat_response deviceInfo host IP

- **WHEN** the device sends `device.online` with `payload.stat.deviceInfo`
- **THEN** `payload.stat.deviceInfo.hostIp` MUST equal the value that would appear as `payload.data.deviceInfo.hostIp` in a contemporaneous `command.stat_response` built in the same process
