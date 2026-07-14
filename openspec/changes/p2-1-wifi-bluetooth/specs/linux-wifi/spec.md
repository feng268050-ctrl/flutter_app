## ADDED Requirements

### Requirement: Abstract Wi-Fi controller API for Linux client

The system SHALL provide a reusable Dart `WifiController` abstraction that exposes radio enablement, scan of visible networks, connect/disconnect/forget (including hidden SSIDs), wlan0 IPv4 mode, and connection status streams. Linux SHALL implement the abstraction using on-demand wpa_supplicant control without NetworkManager. Callers MUST depend on the abstract type, not the Linux concrete class.

#### Scenario: Radio enable starts deferred stack

- **WHEN** the controller is asked to enable Wi-Fi while the radio is off
- **THEN** the Linux implementation brings up the deferred Wi-Fi stack (`wifibt-init` / `wlan0` / `wpa_supplicant`) without requiring those units to be in `multi-user.target.wants`

#### Scenario: Scan returns visible access points

- **WHEN** Wi-Fi radio is on and scan is requested
- **THEN** the controller returns access points including SSID when broadcast and a signal strength indicator when available

#### Scenario: Connect to visible WPA2-PSK network

- **WHEN** the user connects to a visible WPA2-PSK network with a correct passphrase
- **THEN** connection state reaches connected with a non-empty wlan0 IPv4 address when IPv4 mode is DHCP and DHCP succeeds

#### Scenario: Connect to hidden SSID

- **WHEN** the user connects with a manually entered SSID, passphrase, and hidden=true
- **THEN** the Linux implementation configures wpa with `scan_ssid=1` (or equivalent) and attempts association without requiring that SSID to appear in a prior scan result list

#### Scenario: Forget removes persisted network

- **WHEN** forget is called for a saved SSID
- **THEN** that network is removed from the persistent wpa configuration and is no longer listed as saved

#### Scenario: Failures do not crash the process

- **WHEN** association or IP configuration fails
- **THEN** the controller emits a failed/disconnected status and MUST NOT terminate the Flutter process

### Requirement: wlan0 IPv4 supports DHCP and static modes

The Linux Wi-Fi path SHALL support selecting **DHCP** or **static** IPv4 configuration for **wlan0 only**. Static mode SHALL apply address, prefix length, and optional gateway/DNS without modifying eth0. DHCP mode SHALL invoke a wlan0-only DHCP helper after association.

#### Scenario: DHCP client targets wlan0 only

- **WHEN** IPv4 mode is DHCP and association completes
- **THEN** a DHCP client runs for `wlan0` and eth0 addressing is unchanged by that helper

#### Scenario: Static IPv4 applied on wlan0

- **WHEN** IPv4 mode is static with a valid address and prefix length
- **THEN** `wlan0` carries that address/prefix and eth0 addressing is unchanged

#### Scenario: IPv4 mode persists

- **WHEN** static or DHCP configuration is saved and the HMI process restarts
- **THEN** `getIpv4Config` returns the last saved mode and static fields

### Requirement: Wi-Fi credentials persist across HMI restarts

Saved networks SHALL persist in a wpa_supplicant configuration under `/var/lib/lws-hmi/` (or an equivalent documented path) with `update_config` enabled so a later radio enable can reconnect without re-entering the PSK.

#### Scenario: Saved network survives app restart

- **WHEN** a network was saved via connect with save enabled and the HMI process restarts with Wi-Fi later enabled
- **THEN** the saved SSID remains present in the persisted configuration
