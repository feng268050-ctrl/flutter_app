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

### Requirement: OEM profile selects Secrets backend

Board OEM `board_profile.json` SHALL support `secrets_backend` with values `software` or `optee`. `BoardBindings.secrets()` SHALL construct the matching provider. When the field is omitted, sim/emulator/portable-smoke board ids SHALL default to software and other board ids SHALL default to OP-TEE. The active backend SHALL be queryable (`backendId` / `isHardwareBound`) without exposing keys. The implementation MUST NOT silently switch from the selected backend to the other on seal/unseal failure.

#### Scenario: Profile selects software

- **WHEN** `secrets_backend` is `software` (e.g. current ynh960 OEM)
- **THEN** seal/unseal uses the device-bound software KEK implementation
- **AND** the provider reports a software-fallback backend identifier and `isHardwareBound = false`

#### Scenario: Profile selects OP-TEE

- **WHEN** `secrets_backend` is `optee` and OP-TEE / seal TA is available
- **THEN** seal/unseal uses the OP-TEE-backed implementation
- **AND** the provider reports an OP-TEE backend identifier and `isHardwareBound = true`

#### Scenario: Selected OP-TEE unavailable fails closed

- **WHEN** `secrets_backend` is `optee` and TEE or seal TA session fails
- **THEN** seal/unseal fails
- **AND** the implementation MUST NOT silently use the software KEK backend for that call

### Requirement: Device-bound software KEK derives from live hardware factors

When the software backend is active, the KEK SHALL be derived at runtime via HKDF over a canonical multi-factor binding (chip id required plus at least one other distinct factor such as eth/wlan MAC, eMMC CID, or distinct DT serial). The implementation MUST NOT persist a KEK file or a secret salt file on disk for this derivation. Ciphertext sealed on one board MUST fail closed when unsealed with a mismatched binding (e.g. different chip id).

#### Scenario: Software round-trip on bound device

- **WHEN** software Secrets seals plaintext on a board with valid multi-factor material
- **AND** unseals with the same AAD on the same binding
- **THEN** plaintext is recovered

#### Scenario: Factor mismatch fails closed

- **WHEN** a software-sealed blob is unsealed under a different chip id (or other changed binding factor used in the IKM)
- **THEN** unseal fails and MUST NOT return the original plaintext

### Requirement: OP-TEE stack is provisioned for product images

Product images SHALL include the OP-TEE client stack (`tee-supplicant` / `libteec`), DT binding for `/dev/tee*`, and the seal helper/TA build path so that selecting `optee` does not require a separate “enable TEE later” image track. Field seal with a vendor-matched TA signature remains a provisioning dependency, not an API change.

#### Scenario: TEE devices present after product image

- **WHEN** a product image with this change is booted on ynh960-class hardware
- **THEN** `/dev/tee0` (or `teepriv0`) is available and `tee-supplicant` can run

### Requirement: No desktop keyring dependency

The Secrets provider MUST NOT require gnome-keyring, libsecret, KWallet, or a logged-in desktop session.

#### Scenario: Headless seal works

- **WHEN** seal/unseal is invoked on the appliance without a desktop session
- **THEN** the operation does not depend on a userspace keyring daemon
