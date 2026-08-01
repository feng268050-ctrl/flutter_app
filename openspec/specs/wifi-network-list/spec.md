# wifi-network-list Specification

## Purpose

Wireless Network settings list layout: remembered SSIDs (My Networks) vs nearby scan results (Other Networks).

## Requirements

### Requirement: Wireless Network page shows My Networks and Other Networks

When the WLAN radio is on, the Wireless Network settings page SHALL present, below the switch / current-connection group, a **My Networks** section listing remembered SSIDs from HAL `WifiController.savedNetworks()`, then an **Other Networks** section listing scanned access points whose SSID is not in that remembered set. Section labels SHALL be operator-visible via AppLocalizations. When the radio is off, My Networks and Other Networks SHALL NOT be shown.

#### Scenario: Saved SSID appears under My Networks

- **WHEN** the radio is on
- **AND** HAL reports a saved network with SSID `Home`
- **THEN** the My Networks section includes a row for `Home`

#### Scenario: Unsaved scan result appears under Other Networks

- **WHEN** the radio is on
- **AND** a scan result SSID `Cafe` is not in saved networks
- **THEN** the Other Networks section includes a row for `Cafe`
- **AND** My Networks does not list `Cafe`

#### Scenario: Saved SSID excluded from Other Networks

- **WHEN** SSID `Home` is both saved and present in the current scan
- **THEN** `Home` appears under My Networks
- **AND** MUST NOT also appear under Other Networks

#### Scenario: Radio off hides network sections

- **WHEN** the WLAN radio is off
- **THEN** My Networks and Other Networks sections are not shown

### Requirement: My Networks and Other Networks retain connect and details affordances

Tapping a My Networks or Other Networks row SHALL use the same connect / password / busy-dialog behavior as today’s scan list. If the tapped SSID is the currently associated network, the App SHALL open the Wi‑Fi Details page instead of reconnecting. The connected SSID in the top group remains the primary entry to Details when associated.

#### Scenario: Tap other network prompts connect

- **WHEN** the operator taps an Other Networks row for a secured SSID that is not currently associated
- **THEN** the App prompts for a password when required and attempts connect via HAL

#### Scenario: Tap associated SSID opens Details

- **WHEN** Wi‑Fi is associated to SSID `Office`
- **AND** the operator taps that SSID from the top connected row or from My Networks
- **THEN** the Wi‑Fi Details page opens titled `Office`
