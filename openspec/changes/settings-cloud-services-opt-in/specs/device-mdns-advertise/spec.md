## MODIFIED Requirements

### Requirement: Advertise LWS device DNS-SD service

While **LAN enhancement is enabled** and the local connection service is healthy (local HTTP `:5580` accepting connections), the system SHALL advertise a DNS-SD service of type `_lws-device._tcp` on the LAN using Avahi (or equivalent). Advertisement MUST stop when the local HTTP server is down, LAN enhancement is disabled, or the App shuts down. Advertisement MUST NOT depend on cloud/API reachability or on the 云服务 preference.

#### Scenario: Browse finds device when LAN HTTP is up

- **WHEN** LAN enhancement is enabled, the local HTTP server is listening on `:5580`, and mDNS advertise is running
- **AND** a client on the same L2 broadcast domain browses `_lws-device._tcp`
- **THEN** the device service MUST be discoverable with the device SN in TXT

#### Scenario: No advertise when LAN enhancement off

- **WHEN** LAN enhancement is disabled
- **THEN** the system MUST NOT advertise `_lws-device._tcp`
