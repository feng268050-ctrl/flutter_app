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

### Requirement: Backends include OP-TEE preferred and interim software

The system SHALL support at least two backends selectable by board profile or equivalent configuration: (1) **OP-TEE-backed** sealing that uses platform secure storage / HUK-derived protection when available, and (2) **interim software** device-bound sealing for bring-up. The active backend SHALL be queryable (e.g. backend id) without exposing keys. The interim backend MUST be documented as insufficient alone for EN 18031 / RED Delegated Regulation (EU) 2022/30 presumption of conformity.

#### Scenario: Interim backend identifiable

- **WHEN** the interim software backend is active
- **THEN** the provider reports an interim backend identifier
- **AND** product security notes state it is not RED-presumption-grade alone

#### Scenario: OP-TEE backend when configured

- **WHEN** the board profile selects the OP-TEE backend and OP-TEE client stack is available
- **THEN** seal/unseal succeeds using the OP-TEE-backed implementation
- **AND** the provider reports a hardware-bound / OP-TEE backend identifier

### Requirement: No desktop keyring dependency

The Secrets provider MUST NOT require gnome-keyring, libsecret, KWallet, or a logged-in desktop session.

#### Scenario: Headless seal works

- **WHEN** seal/unseal is invoked on the appliance without a desktop session
- **THEN** the operation does not depend on a userspace keyring daemon

### Requirement: Host-testable fake provider

The package SHALL provide a fake or in-memory Secrets provider for host unit tests that round-trips seal/unseal without OP-TEE hardware.

#### Scenario: Fake provider in tests

- **WHEN** host unit tests use the fake provider
- **THEN** seal/unseal round-trips succeed without TEE hardware
