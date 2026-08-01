## ADDED Requirements

### Requirement: HAL exposes a Secrets seal/unseal API

`cyber_hal` SHALL provide an abstract Secrets / KEK provider that can **seal** plaintext with associated data into an opaque blob and **unseal** that blob back to plaintext when the same associated data is supplied. Callers MUST depend on the abstract type, not a concrete OP-TEE or software backend. Key material and unsealed plaintext MUST NOT be written to info-level logs.

#### Scenario: Seal then unseal round-trip

- **WHEN** a caller seals plaintext `P` with AAD `A` via the abstract provider
- **AND** later unseals the blob with the same AAD `A`
- **THEN** the provider returns plaintext equal to `P`

#### Scenario: Wrong AAD fails closed

- **WHEN** a blob was sealed with AAD `A`
- **AND** unseal is attempted with AAD `A'`
- **THEN** unseal fails and MUST NOT return the original plaintext

### Requirement: Hardware OP-TEE is the production Secrets backend

On real appliance board profiles (e.g. ynh960/961/962), the Secrets provider SHALL use an **OP-TEE-backed** implementation that relies on platform secure storage / HUK-derived protection. Product images SHALL include the OP-TEE client stack required for that backend. The active backend SHALL be queryable without exposing keys and SHALL report a hardware-bound / OP-TEE backend identifier when OP-TEE is in use. There SHALL NOT be a separate “bring-up” software mode used as the normal path on those hardware profiles.

#### Scenario: Hardware profile uses OP-TEE

- **WHEN** Secrets is constructed for a real-board product profile and OP-TEE is available
- **THEN** seal/unseal uses the OP-TEE-backed implementation
- **AND** the provider reports a hardware-bound / OP-TEE backend identifier

#### Scenario: No dual prod policy on hardware

- **WHEN** a real-board product profile is active
- **THEN** the default Secrets backend is not software-only

### Requirement: Software KEK only when hardware is unavailable

A software device-bound KEK backend MAY be used only when hardware TEE is unavailable, including emulator / sim board profiles, host unit-test fakes, or an explicit profile that documents hardware absence. When the software fallback is active, the provider SHALL report a distinct software-fallback backend identifier. Product security notes SHALL state that software fallback is not the field production path on real boards.

#### Scenario: Emulator uses software fallback

- **WHEN** Secrets is constructed for an emulator or sim profile without OP-TEE
- **THEN** seal/unseal MAY use the software fallback backend
- **AND** the provider reports a software-fallback backend identifier

#### Scenario: Host fake for tests

- **WHEN** host unit tests use the in-memory fake provider
- **THEN** seal/unseal round-trips succeed without TEE hardware

### Requirement: No desktop keyring dependency

The Secrets provider MUST NOT require gnome-keyring, libsecret, KWallet, or a logged-in desktop session.

#### Scenario: Headless seal works

- **WHEN** seal/unseal is invoked on the appliance without a desktop session
- **THEN** the operation does not depend on a userspace keyring daemon
