## ADDED Requirements

### Requirement: Connected network signal metadata uses SSID representative scan

When resolving scan-backed metadata (signal strength, Wi-Fi standard, lock icon) for the currently connected network on the Wi-Fi list or when navigating to Wi-Fi details, the system SHALL use the SSID aggregation rules from `wifi-scan-ssid-roaming`: prefer the representative scan result for the connected SSID when BSSID-specific scan match is unavailable.

#### Scenario: Connected row uses representative RSSI when BSSID not in scan cache

- **WHEN** the device is connected to SSID `Office-Net`
- **AND** the latest scan contains `Office-Net` on a different BSSID than the active association
- **THEN** the connected row signal indicator MAY use the representative (strongest RSSI) scan result for `Office-Net`
- **AND** the UI MUST still show SSID `Office-Net` exactly once in the list header area
