## Purpose

Define the transport-neutral device **remote snapshot**: the aggregate exposed in WebSocket `command.stat_response` payload field `data`, aligned with legacy packed device state but without a redundant top-level `device` identity object.
## Requirements
### Requirement: Remote snapshot aggregate without connection-local device object

The app SHALL expose a transport-neutral aggregate object (“remote snapshot”) representing the same device-local information previously bundled for periodic cloud push, **excluding** any nested `device` object used only to duplicate connection-local identity on the wire.

#### Scenario: Snapshot fields cover operational context

- **WHEN** the app builds a remote snapshot for export over an approved device channel
- **THEN** the aggregate MUST be structurally capable of carrying: static layout data, device base info, **common settings** (`commonSettings`), live device status, device data, and the current warning list, each as distinct properties of the aggregate
- **AND** the aggregate MUST NOT include root property `advancedSettings`

#### Scenario: Device identity field omitted from snapshot JSON

- **WHEN** the aggregate is serialized as the `data` object for `command.stat_response`
- **THEN** the serialized JSON MUST NOT include a `device` property at the root of `data`

### Requirement: Naming independence from legacy MQTT message types

Types, packages, and public identifiers introduced or repurposed solely for this remote snapshot and its WebSocket serialization SHALL NOT include the substrings `MQTT`, `Mq`, or `MQ` in their names.

#### Scenario: DTO and builder naming

- **WHEN** new or refactored Java types are added to represent the snapshot for WebSocket export
- **THEN** their simple names MUST NOT contain `MQTT`, `Mq`, or `MQ`, and methods that only fill UI version from the installed APK MUST NOT be named with an `Mqtt` suffix

### Requirement: Static data includes resolved dominant consumable label

When the app serializes `staticData` as part of the remote snapshot (the object carried at `command.stat_response` `payload.data` and at `device.online` `payload.stat`, per `device-ws-unified-envelope`), the JSON object for `staticData` MUST always include string field `commonUseText`. Its value MUST be the device-resolved human-readable label for the dominant consumable material type when `commonUse` maps to one, derived with the same material-type mapping as the on-device Frequent Usage presentation for the current app locale.

The JSON object MUST continue to include integer field `commonUse` when a dominant material code is defined, unchanged from prior behavior. When no label can be resolved (for example `commonUse` is null or has no defined mapping), `commonUseText` MUST be the literal ASCII string `unknown` (lowercase).

#### Scenario: Stat response staticData carries text alongside code

- **WHEN** the device sends `command.stat_response` whose `payload.data.staticData.commonUse` is a non-null material type code
- **THEN** the same `staticData` object MUST include `commonUseText` as a non-empty string consistent with that code under the app’s current locale

#### Scenario: Device online matches stat_response staticData shape

- **WHEN** the device sends `device.online` with `payload.stat` that includes `staticData`
- **THEN** `staticData` MUST satisfy the same `commonUseText` rules as in `command.stat_response`’s `payload.data.staticData`

#### Scenario: Unknown dominant material

- **WHEN** the remote snapshot is built and `staticData.commonUse` is null or has no defined mapping
- **THEN** `commonUseText` MUST equal `unknown` (literal string), and consumers MUST treat that value as “no resolvable material label” rather than a localized display name

### Requirement: Real-time process-parameter snapshot is maintained in memory

The app SHALL maintain a complete in-memory `processParameters` snapshot that reflects the latest process-parameter state for both Fast Mode and Engineer Mode. Every accepted process-parameter mutation in either mode MUST update this shared snapshot immediately, and the snapshot representation MUST remain structurally complete for downstream serialization.

#### Scenario: Fast Mode update refreshes shared snapshot

- **WHEN** Fast Mode applies a process-parameter change
- **THEN** the shared in-memory `processParameters` snapshot MUST be updated in the same processing flow and remain available as a full snapshot object

#### Scenario: Engineer Mode update refreshes shared snapshot

- **WHEN** Engineer Mode applies a process-parameter change
- **THEN** the shared in-memory `processParameters` snapshot MUST be updated in the same processing flow and remain available as a full snapshot object

#### Scenario: Snapshot read returns complete latest view

- **WHEN** a device message builder requests `processParameters` for serialization
- **THEN** it MUST receive a complete snapshot view representing the latest committed parameter state rather than only incremental deltas

### Requirement: Remote snapshot includes lock flag

The remote snapshot aggregate serialized as `command.stat_response` `payload.data` and as `device.online` `payload.stat` SHALL include a boolean JSON field `isLocked` at the root of the snapshot object. The value MUST reflect the current persisted remote lock flag from `device-remote-lock` at serialization time.

#### Scenario: Stat response reports locked device

- **WHEN** the remote lock flag is true and the device sends `command.stat_response`
- **THEN** `payload.data.isLocked` MUST be JSON `true`

#### Scenario: Stat response reports unlocked device

- **WHEN** the remote lock flag is false and the device sends `command.stat_response`
- **THEN** `payload.data.isLocked` MUST be JSON `false`

#### Scenario: Device online matches stat_response lock field

- **WHEN** the device sends `device.online` with a remote snapshot in `payload.stat`
- **THEN** `payload.stat.isLocked` MUST equal the value that would appear as `payload.data.isLocked` in a contemporaneous `command.stat_response`

### Requirement: Remote snapshot includes connected Wi-Fi info object

The remote snapshot aggregate serialized as `command.stat_response` `payload.data` and as `device.online` `payload.stat` SHALL include a JSON object field `wifiInfo` at the root of the snapshot object. When the device is connected to Wi-Fi with usable connection metadata (per the shared connected-Wi-Fi reader used by Settings → Network → Wireless Network → Wi-Fi details), `wifiInfo` MUST be a non-null object whose fields are populated from the same sources as that details screen. When the device is not connected, lacks a usable `WifiInfo`, or has no non-zero `WifiInfo#getIpAddress()`, `wifiInfo` MUST be JSON `null`.

The `wifiInfo` object SHALL include the following camelCase properties when values are available; otherwise each unavailable scalar property MUST be JSON `null`:

| Property | Meaning | Source (same as Wi-Fi details) |
|----------|---------|--------------------------------|
| `ssid` | Network name | Normalized `WifiInfo#getSSID()` |
| `bssid` | BSSID | `WifiInfo#getBSSID()` |
| `capabilities` | Raw security capabilities string | Scan result match or empty → `null` |
| `ipAddress` | IPv4 dotted decimal | `WifiInfo#getIpAddress()` + `WifiStatusUtils.formatIpAddress` |
| `subnetMask` | Subnet mask dotted decimal | `DhcpInfo#netmask` or `LinkProperties` prefix fallback |
| `router` | Default gateway dotted decimal | `DhcpInfo#gateway` |
| `dns` | Primary DNS dotted decimal | `DhcpInfo#dns1` |
| `rssi` | Signal strength (dBm) | `WifiInfo#getRssi()` |
| `linkSpeed` | Link speed (Mbps) | `WifiInfo#getLinkSpeed()` |
| `frequency` | Center frequency (MHz) | `WifiInfo#getFrequency()` |
| `securityType` | Human-readable security label | Derived from `capabilities` (`WPA3`, `WPA2`, `WPA`, `WEP`, `Open`) |
| `macAddress` | Station MAC | `WifiInfo#getMacAddress()` when not masked |

The snapshot object MUST NOT include a `localIP` field.

#### Scenario: Stat response reports full wifiInfo when connected

- **WHEN** the device is connected to Wi-Fi with non-zero `WifiInfo#getIpAddress()` and the device sends `command.stat_response`
- **THEN** `payload.data.wifiInfo` MUST be a non-null object
- **AND** `payload.data.wifiInfo.ipAddress` MUST equal the IP Address row on the Wi-Fi details screen for that connection
- **AND** `payload.data.wifiInfo.subnetMask`, `router`, and `dns` MUST match the Subnet Mask, Router, and DNS rows when those values are available on the details screen

#### Scenario: Stat response reports null wifiInfo without connection

- **WHEN** the device has no connected Wi-Fi usable for snapshot at build time and sends `command.stat_response`
- **THEN** `payload.data.wifiInfo` MUST be JSON `null`
- **AND** `payload.data` MUST NOT contain `localIP`

#### Scenario: Device online matches stat_response wifiInfo field

- **WHEN** the device sends `device.online` with a remote snapshot in `payload.stat`
- **THEN** `payload.stat.wifiInfo` MUST deep-equal the `wifiInfo` object that would appear as `payload.data.wifiInfo` in a contemporaneous `command.stat_response`

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

### Requirement: Remote snapshot deviceInfo includes camera IP

The `deviceInfo` object inside the remote snapshot (`command.stat_response` `payload.data.deviceInfo`, `device.online` `payload.stat.deviceInfo`, and cloud `GET /v1/devices/:sn/stat` `deviceInfo` when sourced from the same snapshot) SHALL include string field `cameraIp`. The value MUST equal `CameraConfig.getCameraIp()` at snapshot build time (ROM `camera_ip` or factory default).

The field MUST NOT be persisted in Room `t_device_info`; it is populated only when assembling `DeviceInfo` for serialization.

#### Scenario: Stat response includes configured camera IP

- **WHEN** effective camera IP is `192.168.0.237` at snapshot build time
- **AND** the device sends `command.stat_response`
- **THEN** `payload.data.deviceInfo.cameraIp` MUST equal `192.168.0.237`

#### Scenario: Device online matches stat_response deviceInfo camera IP

- **WHEN** the device sends `device.online` with `payload.stat.deviceInfo`
- **THEN** `payload.stat.deviceInfo.cameraIp` MUST equal the value that would appear as `payload.data.deviceInfo.cameraIp` in a contemporaneous `command.stat_response` built in the same process

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

