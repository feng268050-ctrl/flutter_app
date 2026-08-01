## ADDED Requirements

### Requirement: Connect preserves other saved Wi-Fi profiles

`WifiController.connect` (Linux wpa D-Bus path) SHALL add or replace the profile for the requested SSID and select it for association **without** removing other saved SSIDs. After select (which may temporarily disable siblings), networks that were Auto Join–enabled before connect SHALL be re-enabled so they remain listed and eligible for later auto-reconnect. Forget remains the only path that removes a saved SSID.

#### Scenario: Second SSID remains after connecting another

- **WHEN** SSID `Home` is already saved
- **AND** the operator connects to a different SSID `Office`
- **THEN** both `Home` and `Office` appear in `savedNetworks()`

#### Scenario: Reconnect does not wipe peers

- **WHEN** `Home` and `Office` are saved
- **AND** the operator connects again to `Home` (new or existing credentials)
- **THEN** `Office` remains in `savedNetworks()`

### Requirement: Saved network Auto Join is readable and settable

`WifiController` SHALL expose whether each saved network auto-joins (or equivalently is not disabled) via `savedNetworks()` (or an adjacent field on `WifiSavedNetwork`) and SHALL provide an API to set Auto Join for a given SSID. Linux SHALL map Auto Join off to wpa_supplicant network `disabled=1` (or D-Bus equivalent) and Auto Join on to `disabled=0`, then persist with SaveConfig. Callers MUST use the abstract controller, not Linux concrete types.

#### Scenario: Set Auto Join off persists

- **WHEN** Auto Join is set off for saved SSID `Home`
- **AND** saved networks are listed again after SaveConfig
- **THEN** `Home` is reported as not auto-joining

#### Scenario: Set Auto Join on clears disabled

- **WHEN** Auto Join is set on for a previously disabled saved SSID `Home`
- **THEN** that network is reported as auto-joining

### Requirement: wlan0 DNS mode supports Automatic and Manual multi-server lists

The Linux Wi‑Fi path SHALL support **DNS Automatic** and **DNS Manual** for **wlan0** independently of whether IPv4 is DHCP or static. Automatic SHALL consume DNS from DHCP / networkd defaults without requiring operator-defined servers. Manual SHALL apply one or more DNS server addresses to the wlan0 networkd configuration (and disable DHCP-provided DNS when IPv4 is DHCP so manual servers take effect). Configuration SHALL persist across HMI restarts and MUST NOT modify eth0.

#### Scenario: Manual DNS with DHCP IP

- **WHEN** IPv4 mode is DHCP and DNS mode is Manual with server `8.8.8.8`
- **THEN** wlan0 is configured such that DNS resolves using `8.8.8.8` rather than only the DHCP-provided DNS

#### Scenario: Automatic DNS clears manual override

- **WHEN** DNS mode is set to Automatic after a Manual configuration
- **THEN** `getIpv4Config` (or DNS-equivalent getter) reports Automatic
- **AND** wlan0 no longer applies the previous manual DNS override

#### Scenario: Multiple Manual DNS servers persist

- **WHEN** DNS mode is Manual with servers `1.1.1.1` and `8.8.8.8`
- **AND** the HMI process restarts
- **THEN** both servers are returned by the getter API

## MODIFIED Requirements

### Requirement: wlan0 IPv4 supports DHCP and static modes

The Linux Wi-Fi path SHALL support selecting **DHCP** or **static** IPv4 configuration for **wlan0 only**. Static mode SHALL apply address, prefix length, and optional gateway without modifying eth0. DHCP mode SHALL invoke a wlan0-only DHCP helper after association. DNS for the link SHALL follow the DNS Automatic / Manual requirement (Manual MAY supply DNS under either IPv4 mode; Automatic MUST NOT require operator-defined servers). Preference get/set SHALL remain on `WifiController.getIpv4Config` / `setIpv4Config` (extended fields allowed) or a documented adjacent API on the same controller.

#### Scenario: DHCP client targets wlan0 only

- **WHEN** IPv4 mode is DHCP and association completes
- **THEN** a DHCP client runs for `wlan0` and eth0 addressing is unchanged by that helper

#### Scenario: Static IPv4 applied on wlan0

- **WHEN** IPv4 mode is static with a valid address and prefix length
- **THEN** `wlan0` carries that address/prefix and eth0 addressing is unchanged

#### Scenario: IPv4 mode persists

- **WHEN** static or DHCP configuration is saved and the HMI process restarts
- **THEN** `getIpv4Config` returns the last saved mode and static fields
