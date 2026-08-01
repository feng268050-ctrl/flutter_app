## Why

The Wi‑Fi settings list is a flat “switch + connected + scan” surface and the Details page dumps addressing, DNS, and radio metrics into one read-only block with a separate IP Settings screen. Operators need an iOS-style layout: remembered networks vs nearby scan results, and a Details page that groups Auto Join, IPv4, DNS, and link metadata with inline Manual editing (same interaction model as Date & Time).

## What Changes

- Restructure the Wireless Network page into three groups when the radio is on:
  1. Switch + current connection (unchanged role)
  2. **My Networks** — remembered / saved SSIDs from HAL `savedNetworks()`
  3. **Other Networks** — scanned SSIDs not already listed under My Networks (section label explicit)
- Regroup the Wi‑Fi Details page:
  - **Auto Join** — single switch row; no section header
  - **IPv4 Address** — Configure IP Automatic / Manual; IP Address, Subnet Mask, Gateway; Manual rows editable inline (Date & Time pattern)
  - **DNS** — Configure DNS Automatic / Manual; DNS Servers list; Manual shows a plus control to add servers
  - **Others** — signal, link speed, security, frequency, MAC, Forget Network
- Fold primary IPv4/DNS editing into Details (**BREAKING** UX vs today’s dedicated Wi‑Fi IP Settings as the only editor); remove or demote that separate page as the primary path
- Extend HAL as needed for Auto Join (wpa network `disabled`) and independent DNS Automatic / Manual (including multi-server list persistence on wlan0)

## Capabilities

### New Capabilities
- `wifi-network-list`: Wireless Network page grouping — My Networks (saved) and Other Networks (scan remainder), labels, exclusion rules, connect/details affordances

### Modified Capabilities
- `wifi-connected-details`: Details layout groups (Auto Join / IPv4 Address / DNS / others); inline Configure IP & Configure DNS; Manual edit interaction; demote separate IP Settings page
- `linux-wifi`: Auto Join get/set for saved networks; DNS mode Automatic vs Manual with multi-server list on wlan0 without touching eth0

## Impact

- App UI: `wifi_settings_page.dart`, `wifi_details_page.dart`, likely retire/repurpose `wifi_ip_settings_page.dart`; l10n ARBs; Settings section headers aligned with Bluetooth / Ethernet patterns
- HAL: `WifiController` / `WifiSavedNetwork` / `WlanIpv4Config` (or sibling DNS config); `wpa_supplicant_dbus` network properties; `NetworkdIpv4Apply` UseDNS / DNS= for DHCP + manual DNS
- Specs: `openspec/specs/wifi-connected-details`, `openspec/specs/linux-wifi`; new `wifi-network-list`
- Tests: list partitioning helpers; HAL DNS/Auto Join unit tests where pure; Flutter widget/smoke where existing patterns allow
