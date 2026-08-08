## ADDED Requirements

### Requirement: Peripheral firmware blobs use the same Ed25519 trust root

Detached Ed25519 signatures for control-board `.bin` and camera `.zip` payloads (host HTTP helpers and cloud publish/download) SHALL use the **same** signing tooling wire format and device-embedded public key as system OTA archives (`ota-sign.sh` / `OTA_SIGNING_KEY` on the host; `/etc/ota/ed25519.pub` on device).

Before Modbus or CGI apply of a host-downloaded or cloud-downloaded peripheral payload, the system SHALL require successful Ed25519 verification of the complete file bytes against that pubkey and the sibling `.sig`. A channel manifest field alone MUST NOT authorize apply.

#### Scenario: Tampered peripheral blob refuses apply

- **WHEN** a staged control-board `.bin` or camera `.zip` fails Ed25519 verification against the embedded pubkey
- **THEN** peripheral apply refuses to start Modbus or CGI flash
- **AND** exits unsuccessful

#### Scenario: Same pubkey verifies system OTA and peripherals

- **WHEN** a rootfs image is inspected for OTA materials
- **THEN** the documented `/etc/ota/ed25519.pub` (or equivalent) is the trust root used for both system OTA `tar.gz` and peripheral firmware blob verification
