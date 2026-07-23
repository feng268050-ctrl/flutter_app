## REMOVED Requirements

### Requirement: Remote snapshot includes LAN IPv4 address

**Reason**: Replaced by structured `wifiInfo` object that includes `ipAddress` plus the rest of the connected Wi-Fi metadata shown on the device Wi-Fi details screen.

**Migration**: Consumers MUST read `wifiInfo.ipAddress` instead of `localIP`. When not connected, `wifiInfo` is JSON `null` (same situations where `localIP` was previously `null`).

## ADDED Requirements

### Requirement: Remote snapshot includes connected Wi-Fi info object

The remote snapshot aggregate serialized as `command.stat_response` `payload.data` and as `device.online` `payload` SHALL include a JSON object field `wifiInfo` at the root of the snapshot object. When the device is connected to Wi-Fi with usable connection metadata (per the shared connected-Wi-Fi reader used by Settings → Network → Wireless Network → Wi-Fi details), `wifiInfo` MUST be a non-null object whose fields are populated from the same sources as that details screen. When the device is not connected, lacks a usable `WifiInfo`, or has no non-zero `WifiInfo#getIpAddress()`, `wifiInfo` MUST be JSON `null`.

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

- **WHEN** the device sends `device.online` with a remote snapshot payload
- **THEN** `payload.wifiInfo` MUST deep-equal the `wifiInfo` object that would appear as `payload.data.wifiInfo` in a contemporaneous `command.stat_response`
