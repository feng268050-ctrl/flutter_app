# device-mdns-service-advertising Specification

## Purpose
TBD - created by syncing change mdns-dnssd-device-onboarding-docs. Update Purpose after review.

## Requirements
### Requirement: Device SHALL advertise discoverable service via mDNS DNS-SD
The HMI device application MUST publish a DNS-SD service on LAN using the configured service type so that mobile apps can discover available devices.

#### Scenario: Service published when device is connectable
- **WHEN** device network is ready and local connection service is available
- **THEN** the device publishes the configured DNS-SD service instance on LAN

#### Scenario: Service unpublished when device is not connectable
- **WHEN** network is unavailable or local connection service is unhealthy
- **THEN** the device SHALL unpublish discovery service until conditions recover

### Requirement: Device SHALL expose stable metadata for mobile discovery
The advertised service MUST include normalized TXT metadata with required keys: `sn`, `model`, `system_version`, `api_ver`, and `connect_proto`.

#### Scenario: Valid metadata advertisement
- **WHEN** service is published
- **THEN** all required TXT fields are present and conform to documented format constraints

#### Scenario: Metadata validation failure
- **WHEN** required TXT metadata cannot be produced
- **THEN** the device SHALL NOT publish the service and SHALL emit a diagnosable error log

### Requirement: Device SHALL maintain advertisement lifecycle on network changes
The device MUST re-create service advertisement when LAN configuration changes, including IP changes and Wi-Fi reconnect events.

#### Scenario: IP changed after reconnect
- **WHEN** device reconnects and obtains a new IP
- **THEN** previous service advertisement is withdrawn and a new advertisement is published with updated endpoint

#### Scenario: Service type collision handled
- **WHEN** instance name conflict occurs on LAN
- **THEN** the device keeps stable `sn` metadata and publishes with conflict-resolved instance naming

### Requirement: Device SHALL keep identity semantics consistent with QR/SN binding
The `sn` exposed via discovery MUST map to the same canonical identity used by existing mobile QR-code and SN binding flows.

#### Scenario: Same device via different onboarding entries
- **WHEN** mobile app binds via QR/SN and also discovers via LAN
- **THEN** backend systems resolve both entries to the same canonical device record
