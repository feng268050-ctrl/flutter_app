# wifi-connected-details Specification

## Purpose
Wi-Fi Details and IP Settings pages for connected hotspots (lws-ui WifiDetails parity).

## Requirements

### Requirement: Connected hotspot opens a Wi-Fi Details page

When Wi‑Fi is associated with a non-empty SSID, the Wi‑Fi settings surface SHALL navigate to a **Wi‑Fi Details** page for that hotspot (lws-ui `WifiDetails` parity) instead of using a bottom sheet as the primary details UX. The Details page title SHALL be the SSID when available. Details chrome SHALL use CyberUI / shared Settings scaffold (page status bar) consistent with other Settings sub-pages. Operator-visible strings SHALL use AppLocalizations.

#### Scenario: Connected row opens Details

- **WHEN** Wi‑Fi is connected to SSID `Office`
- **AND** the operator taps the connected network row on the Wi‑Fi page
- **THEN** the App opens the Wi‑Fi Details page titled `Office`

#### Scenario: Details replaces bottom-sheet primary path

- **WHEN** the operator inspects the connected hotspot from Wi‑Fi settings
- **THEN** the primary navigation target is the Wi‑Fi Details page
- **AND** MUST NOT rely on a modal bottom sheet as the only details surface

### Requirement: Wi-Fi Details shows link and addressing fields

The Wi‑Fi Details page SHALL present read-only rows for at least: IP Mode (DHCP / Static), IP Address, Subnet Mask, Gateway, DNS, Signal Strength, Link Speed, Security, Frequency, and MAC Address. Missing values SHALL show a localized Unavailable / `-` placeholder. Values SHALL refresh when the page is shown (e.g. on resume) from HAL Wi‑Fi connection / link state and saved IPv4 preferences.

#### Scenario: DHCP mode displayed

- **WHEN** the saved wlan IPv4 mode is DHCP and the page opens
- **THEN** IP Mode shows the localized DHCP label

#### Scenario: Signal strength format

- **WHEN** the current association reports signal strength `-55` dBm
- **THEN** Signal Strength displays a string including `-55` and `dBm`

#### Scenario: Unavailable IP

- **WHEN** the association has no IPv4 address yet
- **THEN** IP Address shows Unavailable or `-`

### Requirement: Wi-Fi Details offers IP Settings and Forget Network

The Wi‑Fi Details page SHALL provide **IP Settings** (navigates to Wi‑Fi IP Settings) and **Forget Network** actions. Forget Network SHALL confirm via CyberUI dialog, then forget the SSID via HAL `WifiController.forget` (and any matching saved IPv4 profile cleanup already owned by HAL), then leave the Details page.

#### Scenario: Forget confirms then removes

- **WHEN** the operator taps Forget Network and confirms
- **THEN** HAL forget is invoked for the current SSID
- **AND** the Details page is closed

#### Scenario: IP Settings opens editor

- **WHEN** the operator taps IP Settings
- **THEN** the Wi‑Fi IP Settings page opens

### Requirement: Wi-Fi IP Settings edits DHCP or static addressing

The Wi‑Fi IP Settings page SHALL let the operator choose DHCP or Static via CyberUI segmented control and, in Static mode, edit address / subnet / gateway / DNS through CyberIME-backed dialogs. **Apply** SHALL persist and apply configuration through the existing wlan0 IPv4 HAL path (`WlanIpv4Config` / `setIpv4Config` equivalent) without modifying eth0.

#### Scenario: Apply static config

- **WHEN** the operator selects Static, enters a valid address and prefix, and taps Apply
- **THEN** HAL is asked to apply that static wlan0 configuration

#### Scenario: Apply DHCP

- **WHEN** the operator selects DHCP and taps Apply
- **THEN** HAL is asked to use DHCP for wlan0
