# hal-secrets-kek Specification

## Purpose

Shared HAL Secrets seal/unseal API with OEM-selected backends (OP-TEE or
device-bound software KEK). On product OP-TEE, the seal KEK is HUK-wrapped into
Vendor Storage so its lifetime matches VS-hosted sealed secrets (cloud Ed25519)
across A/B upgrades and factory userdata wipe without requiring RPMB-capable BL32.

## Requirements
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

- **WHEN** `secrets_backend` is `software` (e.g. sim / emulator OEM)
- **THEN** seal/unseal uses the device-bound software KEK implementation
- **AND** the provider reports a software-fallback backend identifier and `isHardwareBound = false`

#### Scenario: Profile selects OP-TEE

- **WHEN** `secrets_backend` is `optee` (e.g. current ynh960 OEM) and OP-TEE / seal TA is available
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

### Requirement: OP-TEE seal KEK persists via HUK-wrapped Vendor Storage

When `secrets_backend` is `optee`, the seal TA’s AES KEK SHALL be recoverable after A/B rootfs replacement and after factory wipe of userdata/REE TEE FS, without regenerating caller secrets. The system SHALL persist only a **HUK-bound wrapped** representation of that KEK in Vendor Storage at the ID defined by `vendor-storage-identity`. Plaintext KEK MUST NOT be written to Vendor Storage, REE filesystem paths, or logs. Unwrapping and use of the KEK MUST occur inside the TEE (seal TA). REE FS under the configured tee-supplicant parent (e.g. `/userdata/tee`) MAY cache the KEK for performance but MUST NOT be the sole durable store. If HUK-bound wrap is unavailable on the device BL32, the implementation MUST fail closed for persistence bootstrap and MUST NOT store plaintext KEK in Vendor Storage. RPMB (`TEE_STORAGE_PRIVATE_RPMB`) remains optional future work when vendor BL32 enables it; it is not required for this persistence path.

#### Scenario: Round-trip after REE TEE FS wipe

- **WHEN** an OP-TEE seal KEK has been wrapped and stored in Vendor Storage
- **AND** REE TEE FS under the configured parent path is deleted
- **AND** `tee-supplicant` is restarted
- **THEN** seal/unseal of a previously sealed blob with the same AAD still recovers the original plaintext

#### Scenario: Cloud Ed25519 seed unchanged across KEK migrate

- **WHEN** a device has a Vendor Storage ID 22 cloud Ed25519 sealed blob unsealable under the current KEK
- **AND** the operator migrates the seal KEK into the HUK-wrapped Vendor Storage form
- **THEN** unseal of ID 22 with the same AAD yields the same private-key seed as before migrate
- **AND** the implementation MUST NOT generate a new Ed25519 keypair as part of KEK migrate

#### Scenario: Plaintext KEK forbidden in Vendor Storage

- **WHEN** inspecting the Vendor Storage item for the wrapped seal KEK
- **THEN** the value MUST be the opaque wrap blob (magic/version/nonce/tag/ciphertext) only
- **AND** MUST NOT be the raw 32-byte AES KEK

### Requirement: Seal KEK wrap uses TEE-only HUK-bound key material

The wrap key used to protect the seal KEK SHALL be obtained inside the TEE from hardware-bound material (OP-TEE system PTA `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` or an equivalent vendor-supported HUK derivation available to the seal TA). The wrap key MUST NOT be derived solely in REE from sysfs/DT factors. Wrap AAD and format version SHALL be frozen (`seal-kek-wrap-v1` / `LWSK` v1) so that TA UUID or AAD changes are treated as intentional breaking migrations.

#### Scenario: Wrap key not available fails closed

- **WHEN** the seal TA cannot obtain HUK-bound wrap key material on the running BL32
- **THEN** bootstrap that would persist a new KEK into Vendor Storage fails
- **AND** the system MUST NOT write plaintext KEK to Vendor Storage as a fallback
