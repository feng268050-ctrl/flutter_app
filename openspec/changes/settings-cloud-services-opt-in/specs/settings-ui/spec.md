## MODIFIED Requirements

### Requirement: Common Settings Network includes Wi-Fi, proxy, Ethernet, and Bluetooth

Common Settings SHALL include a Network group with operator entry points for:

- Wi‑Fi
- Ethernet (when the product exposes it)
- HTTP Proxy
- **LAN SSH debug** (immediately after HTTP Proxy in the same Network group)
- Bluetooth
- **Cloud services** (云服务; immediately after Bluetooth in the same Network group) — opens the Cloud services sub-page defined by `settings-cloud-services`

LAN SSH debug SHALL control on-demand LAN/WLAN SSH via `SshDebug` (not persisted across reboot as an enabled-at-boot service; default off). USB OTG mode selection lives under Input → USB OTG, not as a Network row. Cloud Worker connectivity and LAN HTTP `:5580`/mDNS MUST NOT appear as always-on implicit behavior; they are controlled from the Cloud services page.

#### Scenario: Network entries reachable

- **WHEN** the operator opens Common Settings → Network
- **THEN** Wi‑Fi, HTTP Proxy, LAN SSH debug (after Proxy), Bluetooth, and Cloud services (after Bluetooth) entries are available under Network

#### Scenario: LAN SSH toggle enable

- **WHEN** the operator turns LAN SSH debug on from Settings
- **THEN** `SshDebug` is asked to enable LAN SSH debug

#### Scenario: Cloud services opens sub-page

- **WHEN** the operator taps Cloud services under Network
- **THEN** the Cloud services settings sub-page is shown
