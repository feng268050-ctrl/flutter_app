## MODIFIED Requirements

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
