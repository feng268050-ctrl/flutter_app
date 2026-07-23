# wlan-static-ip Specification

## Purpose
TBD - created by archiving change wlan-static-ip-http-proxy. Update Purpose after archive.
## Requirements
### Requirement: Per-network WiFi IP profile storage

The system SHALL persist a `WifiNetworkProfile` per saved Wi‑Fi network keyed by **SSID plus security type** (not BSSID alone). Each profile SHALL include `WifiIpConfig` with mode `DHCP` or `STATIC`. For `STATIC`, the system SHALL store IPv4 address, prefix length (internal representation), gateway, DNS1 (required), and optional DNS2. UI MAY accept dotted-decimal subnet mask input but MUST convert to prefix length before persistence.

#### Scenario: Default profile is DHCP for new network

- **WHEN** the user connects to a network that has no stored profile
- **THEN** the system SHALL treat the profile mode as `DHCP` unless the user explicitly chooses `STATIC` in the join or edit flow

#### Scenario: Profile key distinguishes security types

- **WHEN** two networks share the same SSID but differ in security type
- **THEN** the system MUST store and retrieve separate IP profiles for each

### Requirement: Static IP validation before connect or save

The system SHALL validate static IP parameters through `WifiIpConfigValidator` before applying configuration or persisting a profile. Validation MUST reject invalid IPv4, invalid prefix, network/broadcast addresses as host IP, missing DNS1 in STATIC mode, wlan0 IP equal to camera IP, and wlan0 IP equal to current eth0 IP.

#### Scenario: Invalid static config blocks connect

- **WHEN** the user submits STATIC settings with an invalid IPv4 or missing DNS1
- **THEN** the system MUST NOT call `WifiManager` connect/update
- **AND** MUST show actionable validation feedback

#### Scenario: Camera IP conflict rejected

- **WHEN** the user enters a STATIC IP identical to `CameraConfig.CAMERA_IP`
- **THEN** the system MUST reject the configuration before connect

### Requirement: Privileged apply of DHCP or STATIC on WifiConfiguration

The system SHALL apply IP mode through `WifiIpConfigApplier` when building or updating `WifiConfiguration`. STATIC mode MUST set static IP assignment with link address, gateway, and DNS. Switching to DHCP MUST clear any prior `StaticIpConfiguration` on the same configuration.

#### Scenario: STATIC apply sets L3 parameters

- **WHEN** the user connects with a valid STATIC profile
- **THEN** the saved `WifiConfiguration` MUST use static IP assignment with the configured address, gateway, and DNS

#### Scenario: DHCP switch clears static residue

- **WHEN** the user changes a network from STATIC to DHCP and reconnects
- **THEN** the system MUST clear static IP fields on the `WifiConfiguration` before reconnect

### Requirement: WiFi connection coordinator orchestrates connect

`WifiConnectionCoordinator` SHALL be the single entry for connect requests carrying `WifiConnectRequest` (ssid, password, securityType, ipConfig). It MUST validate, persist profile when appropriate, delegate applier + `SystemWifiManagerUtils`, and surface structured success/failure to the UI.

#### Scenario: Join dialog connect uses coordinator

- **WHEN** the user submits the Wi‑Fi join dialog with password and IP settings
- **THEN** the app MUST invoke `WifiConnectionCoordinator.connect` with a populated `WifiConnectRequest`

### Requirement: Camera route policy reacts to wlan0 LinkProperties

When wlan0 IPv4 addressing changes (including STATIC apply), `CameraEth0WifiNetworkCallback` MUST handle `onLinkPropertiesChanged` and reconfigure eth0 routes using `CameraRoutePolicy`: `CAMERA_SUBNET_ROUTE` (`camera/24 → eth0`) when wlan0 and camera LAN do not overlap; `CAMERA_HOST_ROUTE` (`camera/32 → eth0`) when they overlap on the same `/24`.

#### Scenario: Non-overlapping wlan0 uses subnet route

- **WHEN** wlan0 is `10.0.0.50/24` and camera is `192.168.1.100`
- **THEN** eth0 routing MUST use the camera `/24` subnet route policy

#### Scenario: Overlapping wlan0 uses host route

- **WHEN** wlan0 is `192.168.1.50/24` and camera is `192.168.1.100`
- **THEN** eth0 routing MUST use `/32` to the camera host only and MUST NOT install a broad `192.168.1.0/24` route on eth0 that hijacks customer LAN traffic

### Requirement: WiFi link snapshots separate desired vs actual state

The system SHALL expose `WifiAssociationSnapshot` (SSID, BSSID, RSSI, security, association state) and `WifiLinkSnapshot` (IPv4, prefix, gateway, DNS from `LinkProperties`) distinct from `WifiNetworkProfileStore` desired configuration.

#### Scenario: Associated without IP is distinguishable

- **WHEN** Wi‑Fi is associated but `LinkProperties` has no usable IPv4
- **THEN** consumers MUST be able to detect ASSOCIATED without L3_READY

