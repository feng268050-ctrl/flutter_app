## ADDED Requirements

### Requirement: Advertise LWS device DNS-SD service

While the local connection service is healthy (local HTTP `:5580` accepting connections), the system SHALL advertise a DNS-SD service of type `_lws-device._tcp` on the LAN using Avahi (or equivalent). Advertisement MUST stop when the local HTTP server is down or the App shuts down. Advertisement MUST NOT depend on cloud/API reachability.

#### Scenario: Browse finds device when LAN HTTP is up

- **WHEN** the local HTTP server is listening on `:5580` and mDNS advertise is running
- **AND** a client on the same L2 broadcast domain browses `_lws-device._tcp`
- **THEN** the device service MUST be discoverable with the device SN in TXT

### Requirement: TXT metadata contract

The advertised TXT record SHALL include required keys: `sn`, `model`, `system_version`, `api_ver`, `connect_proto`. For this Linux HMI, `api_ver` MUST be `1`, `connect_proto` MUST be `http`, and the advertised port MUST be `5580` (the working LAN HTTP API). `sn`, `model`, and `system_version` MUST match Device Information identity sources.

#### Scenario: TXT describes HTTP on 5580

- **WHEN** the service is advertised
- **THEN** TXT `connect_proto` MUST equal `http`
- **AND** the resolved service port MUST be `5580`
- **AND** TXT `sn` MUST equal the resolved device SN

### Requirement: Wi-Fi or LAN link gated publish

The system SHALL publish mDNS when a suitable LAN/Wi‑Fi (or Ethernet LAN) address exists for clients to connect, and SHALL withdraw the service when no usable LAN address remains.

#### Scenario: No LAN address means no advertise

- **WHEN** the device has no usable LAN IPv4/IPv6 address for clients
- **THEN** the system MUST NOT leave a stale `_lws-device._tcp` advertisement pointing at an unreachable host
