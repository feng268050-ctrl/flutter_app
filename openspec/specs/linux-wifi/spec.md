# linux-wifi Specification

## Purpose

Linux Wi-Fi client stack for the HMI: on-demand wpa_supplicant, wlan0 DHCP/static IPv4, and a reusable Dart `WifiController` abstraction (no NetworkManager).
## Requirements
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

### Requirement: Wi-Fi credentials persist across HMI restarts

Saved networks SHALL persist in a wpa_supplicant configuration under `/var/lib/wpa_supplicant/` (or an equivalent documented path) with `update_config` enabled so a later radio enable can reconnect without re-entering the PSK. **Operator PSK / passphrase secrets SHALL persist in the encrypted Wi‑Fi credential vault** (see `wifi-credential-secure-storage`), sealed via HAL Secrets (`hal-secrets-kek`), not as plaintext `psk=` / passphrase lines in `wpa_supplicant.conf`. After connect or migration, SaveConfig MUST NOT leave plaintext PSK material in the conf file. Reconnect after reboot SHALL use vault inject into wpa memory (`mem_only_psk` or equivalent).

#### Scenario: Saved network survives app restart

- **WHEN** a network was saved via connect with save enabled and the HMI process restarts with Wi-Fi later enabled
- **THEN** the saved SSID remains present in the persisted configuration

#### Scenario: PSK not plaintext in conf after save

- **WHEN** a PSK-protected network is connected and configuration is saved
- **THEN** `wpa_supplicant.conf` does not contain a plaintext `psk=` or passphrase assignment for that network
- **AND** the encrypted vault contains the secret for that SSID

#### Scenario: Reboot reconnect without re-entry

- **WHEN** a PSK-protected network was saved and the device reboots with Wi-Fi enabled
- **THEN** association can complete using the vault-injected PSK without the operator re-entering the passphrase

### Requirement: Settings daemons outside HMI cgroup

Long-lived Wi‑Fi and wlan0 DHCP processes SHALL run under dedicated systemd units (`wlan-wpa.service`, `wlan-dhcp.service`) that are not part of `hmi.service`'s cgroup. Enabling Wi‑Fi from the HMI MUST start those units (or equivalent escaped helpers) and MUST NOT leave `wpa_supplicant` started solely as a child of the HMI process tree.

#### Scenario: HMI restart keeps Wi-Fi

- **WHEN** Wi‑Fi is associated with an address and the operator restarts `hmi.service`
- **THEN** `wlan0` remains associated with an IPv4 address and LAN SSH to that address (if enabled) remains usable

### Requirement: Wanted marker for Wi-Fi radio

When Wi‑Fi radio is enabled successfully, the system SHALL create `/var/lib/wpa_supplicant/wifi-wanted`. When radio is disabled, that file SHALL be removed.

#### Scenario: Enable writes wanted

- **WHEN** the operator enables Wi‑Fi radio successfully
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` exists

#### Scenario: Disable clears wanted

- **WHEN** the operator disables Wi‑Fi radio
- **THEN** `/var/lib/wpa_supplicant/wifi-wanted` is absent and the Wi‑Fi stack is torn down

### Requirement: Wi-Fi modem bring-up loads firmware from OEM radio pack

On boards that use an OEM `helpers.wifi_modem` (or equivalent) for combo Wi‑Fi/BT, the bring-up path SHALL treat the board OEM `radio/firmware/` directory as the authoritative source of module firmware blobs, ensuring driver search paths can resolve the required AIC (or board-specific) files. Bring-up MUST NOT depend on a rootfs multi-vendor firmware kitchen sink. Missing OEM radio firmware MUST soft-fail without crashing the HMI process.

#### Scenario: ynh960 bringup finds fmacfw under OEM

- **WHEN** `/oem` is mounted with the ynh960 radio pack and Wi‑Fi modem bring-up runs
- **THEN** the helper MUST successfully resolve `fmacfw_8800d80_u02.bin` via the OEM radio pack (directly or via symlink/bind into the driver firmware path)

#### Scenario: Missing OEM radio does not crash HMI

- **WHEN** OEM radio firmware is absent and modem bring-up is invoked
- **THEN** bring-up MUST fail soft (log / non-zero) and the HMI App process MUST remain running

### Requirement: Wi-Fi country follows product Country preference

Linux Wi‑Fi client bring-up and runtime configuration SHALL use the product Country preference (ISO alpha-2) for wpa_supplicant `country=` (conf upsert + runtime `wpa_cli set country`, optional `iw reg set` when packaged). Image seed configuration and script defaults SHALL use `country=US` (not `CN`) so pre-App bring-up matches the product default. When the App applies a Country change, Wi‑Fi SHALL update the effective country without requiring a full device reboot. Soft-fail is allowed when the radio is down; the HMI MUST NOT crash.

#### Scenario: Image seed is US

- **WHEN** rootfs `wpa_supplicant.conf` and Wi‑Fi bring-up script country defaults are inspected
- **THEN** they specify `country=US`

#### Scenario: Runtime country follows App preference

- **WHEN** the product App applies Country `GB` while the Wi‑Fi stack is available
- **THEN** wpa effective country is `GB`

