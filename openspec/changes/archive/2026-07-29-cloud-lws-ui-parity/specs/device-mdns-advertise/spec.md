## MODIFIED Requirements

### Requirement: Wi-Fi or LAN link gated publish

The system SHALL publish mDNS when a suitable LAN/Wi‑Fi (or Ethernet LAN) address exists for clients to connect, and SHALL withdraw the service when no usable LAN address remains (including Wi‑Fi disconnect while the App process stays alive).

#### Scenario: No LAN address means no advertise

- **WHEN** the device has no usable LAN IPv4/IPv6 address for clients
- **THEN** the system MUST NOT leave a stale `_lws-device._tcp` advertisement pointing at an unreachable host

#### Scenario: Wi-Fi drop withdraws advertisement

- **WHEN** mDNS was advertising while Wi‑Fi provided a usable LAN address
- **AND** Wi‑Fi drops such that no usable LAN address remains
- **THEN** the system MUST withdraw the `_lws-device._tcp` advertisement
