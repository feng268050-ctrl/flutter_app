## ADDED Requirements

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
