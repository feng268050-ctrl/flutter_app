## MODIFIED Requirements

### Requirement: Wi-Fi Details shows link and addressing fields

The Wi‑Fi Details page SHALL present fields in these groups (CyberUI Settings chrome, AppLocalizations):

1. **Auto Join** — a single switch row in a group with **no** section header.
2. **IPv4 Address** — section header; Configure IP (Automatic / Manual); IP Address; Subnet Mask; Gateway.
3. **DNS** — section header; Configure DNS (Automatic / Manual); DNS Servers list.
4. **Others** — section for at least Signal Strength, Link Speed, Security, Frequency, and MAC Address (read-only), plus Forget Network.

Missing link values SHALL show a localized Unavailable / `-` placeholder. Values SHALL refresh when the page is shown from HAL connection / link state and saved wlan IPv4 / DNS preferences. IP Mode SHALL be presented as Configure IP Automatic (DHCP) or Manual (static), not as a separate unlabeled flat dump with a mandatory IP Settings navigation row.

#### Scenario: Auto Join has no section header

- **WHEN** the Details page opens
- **THEN** Auto Join is shown as a switch
- **AND** no section header label is shown solely for that Auto Join group

#### Scenario: IPv4 Address group present

- **WHEN** the Details page opens
- **THEN** an IPv4 Address section includes Configure IP, IP Address, Subnet Mask, and Gateway

#### Scenario: DNS group present

- **WHEN** the Details page opens
- **THEN** a DNS section includes Configure DNS and DNS Servers

#### Scenario: Signal strength format

- **WHEN** the current association reports signal strength `-55` dBm
- **THEN** Signal Strength displays a string including `-55` and `dBm`

#### Scenario: Unavailable IP

- **WHEN** the association has no IPv4 address yet
- **THEN** IP Address shows Unavailable or `-`

### Requirement: Wi-Fi Details offers IP Settings and Forget Network

The Wi‑Fi Details page SHALL provide **Forget Network** (confirm via CyberUI dialog, then HAL `WifiController.forget`, then leave Details). IPv4 and DNS configuration SHALL be edited **on the Details page** (Configure IP / Configure DNS and Manual field edits). The App MUST NOT require a separate Wi‑Fi IP Settings page as the primary editor for these fields.

#### Scenario: Forget confirms then removes

- **WHEN** the operator taps Forget Network and confirms
- **THEN** HAL forget is invoked for the current SSID
- **AND** the Details page is closed

#### Scenario: Manual IP edited on Details

- **WHEN** Configure IP is Manual
- **AND** the operator edits IP Address via the Details page CyberIME flow
- **THEN** HAL `setIpv4Config` (or equivalent) is invoked with the updated addressing
- **AND** the App does not require navigating to a separate IP Settings page to apply

## ADDED Requirements

### Requirement: Auto Join switch controls saved-network auto-reconnect

The Details Auto Join switch SHALL reflect and set whether the current SSID’s saved wpa network is allowed to auto-reconnect (HAL Auto Join / `disabled` mapping). Toggling SHALL persist via HAL and survive process restart for that saved SSID.

#### Scenario: Disable Auto Join

- **WHEN** the operator turns Auto Join off for the associated SSID
- **THEN** HAL records that saved network as not auto-joining
- **AND** a subsequent read shows Auto Join off

### Requirement: Configure IP Automatic vs Manual inline editing

Configure IP **Automatic** SHALL map to DHCP and show IP Address / Subnet Mask / Gateway as non-editable live (or last-known) values. Configure IP **Manual** SHALL map to static IPv4; IP Address, Subnet Mask, and Gateway SHALL be editable via CyberIME-backed dialogs using the same enable-when-manual pattern as Date & Time manual date/time rows. Changes SHALL apply through the existing wlan0 IPv4 HAL path without modifying eth0.

#### Scenario: Switch to Automatic

- **WHEN** the operator selects Configure IP Automatic
- **THEN** HAL is asked to use DHCP for wlan0
- **AND** address rows are not editable

#### Scenario: Manual fields editable

- **WHEN** Configure IP is Manual
- **THEN** IP Address, Subnet Mask, and Gateway rows are tappable for edit

### Requirement: Configure DNS Automatic vs Manual with add control

Configure DNS **Automatic** SHALL use DNS from DHCP / networkd without operator-defined server list editing. Configure DNS **Manual** SHALL show the DNS Servers list as editable and SHALL show a **plus** control to add a DNS server (CyberIME). Manual DNS SHALL persist via HAL for wlan0 (including when Configure IP is Automatic) without modifying eth0. Empty Manual list MAY be rejected or treated as invalid with operator-visible error.

#### Scenario: Manual DNS shows plus

- **WHEN** Configure DNS is Manual
- **THEN** a plus affordance is visible to add a DNS server

#### Scenario: Add DNS server

- **WHEN** Configure DNS is Manual
- **AND** the operator adds server `1.1.1.1` via the plus flow
- **THEN** DNS Servers includes `1.1.1.1`
- **AND** HAL persists the manual DNS configuration for wlan0

#### Scenario: Automatic DNS not editable

- **WHEN** Configure DNS is Automatic
- **THEN** the plus affordance is not offered for adding DNS servers

## REMOVED Requirements

### Requirement: Wi-Fi IP Settings edits DHCP or static addressing

**Reason:** IPv4 / DNS editing moves onto the Wi‑Fi Details page (inline Configure IP / Configure DNS). A dedicated IP Settings page is no longer the primary or required editor.

**Migration:** Implement Configure IP / Configure DNS and Manual field editors on `WifiDetailsPage`; remove or stop linking `WifiIpSettingsPage` from Settings / Demo.
