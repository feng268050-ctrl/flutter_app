## ADDED Requirements

### Requirement: Cloud services Network entry and sub-page

Common Settings SHALL include a **云服务** (Cloud services) navigation row in the Network group that opens a dedicated settings sub-page. The Network group order SHALL be: Wi‑Fi, HTTP Proxy, LAN SSH debug, Bluetooth, then Cloud services. The sub-page SHALL present two independent toggle rows—**云服务** and **局域网增强**—and SHALL show explanatory footer text below the toggles describing each plane. Operator-visible strings SHALL come from App localization (EN + ZH parent ARBs; child locales via existing l10n sync).

#### Scenario: Entry reachable from Network

- **WHEN** the operator opens Common Settings → Network
- **THEN** a Cloud services row is available after Bluetooth

#### Scenario: Sub-page shows two toggles and footer

- **WHEN** the operator opens Cloud services
- **THEN** toggles for 云服务 and 局域网增强 are visible
- **AND** footer help for both planes is visible without obscuring the toggles

### Requirement: Cloud and LAN enhancement preferences default off and persist

The App SHALL persist boolean preferences for cloud services and LAN enhancement under the HMI settings tree (e.g. `/var/lib/hmi/`). Both SHALL default to **false** when unset. Changing a toggle SHALL persist immediately and apply without requiring an HMI process restart. Reboot SHALL restore the last persisted values.

#### Scenario: Fresh install defaults

- **WHEN** preferences files have never recorded cloud/LAN enhancement flags
- **THEN** both 云服务 and 局域网增强 behave as off

#### Scenario: Persist across reboot

- **WHEN** the operator enables 局域网增强 and reboots
- **THEN** 局域网增强 remains on after Settings restore / runtime start

### Requirement: Enabling a plane starts it when network allows

When the operator turns **云服务** on, the system SHALL begin cloud origin probe and device WebSocket connect/reconnect per existing cloud lifecycle rules once a suitable network is available (or immediately if already available). When the operator turns **局域网增强** on, the system SHALL start the LAN HTTP server on `:5580` and MAY publish mDNS when local HTTP is healthy and a usable LAN address exists. Enabling one plane MUST NOT force-enable the other.

#### Scenario: Enable cloud while online

- **WHEN** a suitable network is up and the operator enables 云服务
- **THEN** the runtime attempts Worker probe / WebSocket connect without requiring reboot

#### Scenario: Enable LAN enhancement

- **WHEN** the operator enables 局域网增强
- **THEN** the LAN HTTP server is started (bind failure remains non-fatal per local HTTP rules)

#### Scenario: Enable while offline then come online

- **WHEN** 云服务 is enabled while no suitable network exists
- **AND** a suitable network later becomes available
- **THEN** the system attempts cloud connect without requiring the operator to toggle again

### Requirement: Disabling a plane stops it

When the operator turns **云服务** off, the system SHALL disconnect the device WebSocket (if any), MUST NOT auto-reconnect while the preference remains off, and MUST NOT run enrollment prompts that depend on cloud auth failure. When the operator turns **局域网增强** off, the system SHALL stop the LAN HTTP server and withdraw mDNS advertisement.

#### Scenario: Disable cloud stops WS

- **WHEN** a cloud WebSocket is connected and the operator disables 云服务
- **THEN** the socket is closed and auto-reconnect does not run until 云服务 is enabled again

#### Scenario: Disable LAN stops HTTP and mDNS

- **WHEN** LAN HTTP and mDNS are active and the operator disables 局域网增强
- **THEN** `:5580` is no longer accepting connections and `_lws-device._tcp` is withdrawn
