## Purpose

Wi-Fi scan list presentation: one row per SSID with strongest-RSSI representative AP (display-layer roaming).

## Requirements

### Requirement: Scan results are unique by SSID in the Wi-Fi list

The system SHALL present at most one list row per non-empty Wi-Fi SSID in the Wireless Network scan list (`WifiActivity` and any shared aggregator consumer). Multiple scan results that share the same normalized SSID but differ in BSSID MUST be collapsed into a single displayed network.

#### Scenario: Multiple APs with the same SSID

- **WHEN** a scan returns three results with SSID `Office-Net` and different BSSIDs
- **THEN** the Wi-Fi list shows exactly one row labeled `Office-Net`
- **AND** the row MUST NOT duplicate the same SSID under separate entries

#### Scenario: Empty or unknown SSID results are omitted

- **WHEN** a scan result has an empty SSID or normalized equivalent of `<unknown ssid>`
- **THEN** that result MUST NOT appear as a list row

### Requirement: Representative AP is chosen by strongest RSSI

For each SSID group, the system SHALL select the scan result with the highest RSSI (`ScanResult.level`) as the representative AP for display (signal icon, Wi-Fi standard label, and capabilities used for join dialog).

#### Scenario: Stronger AP wins within SSID group

- **WHEN** two scan results share SSID `Office-Net` with RSSI -80 and -65 respectively
- **THEN** the displayed row uses the -65 dBm result as the representative
- **AND** the signal strength indicator reflects the representative RSSI

### Requirement: Connected network is not duplicated in the scan list

The system SHALL show the currently connected Wi-Fi network in the dedicated connected row at the top of `WifiActivity` and MUST exclude that SSID from the scanned network list below.

#### Scenario: Connected SSID hidden from scan duplicates

- **WHEN** the device is connected to SSID `Office-Net`
- **AND** the latest scan also contains `Office-Net` on one or more BSSIDs
- **THEN** `Office-Net` appears only in the connected row
- **AND** does not appear again in the available networks list

### Requirement: Display list is sorted by signal strength

After SSID aggregation, available (non-connected) networks in the Wi-Fi list SHALL be sorted by representative RSSI in descending order (strongest first).

#### Scenario: Strongest networks appear first

- **WHEN** aggregated results include SSIDs A (-50), B (-70), and C (-60)
- **THEN** the available list order is A, then C, then B

### Requirement: Connection identity remains SSID-based

SSID aggregation and display roaming MUST NOT change how networks are saved or connected. The system SHALL continue to key saved profiles and connection requests by SSID plus security type, without requiring a specific BSSID for connect or forget flows.

#### Scenario: User joins aggregated row

- **WHEN** the user taps the single displayed row for SSID `Office-Net` and completes join
- **THEN** the connect request uses SSID `Office-Net` and derived security type
- **AND** MUST NOT persist BSSID as the profile storage key
