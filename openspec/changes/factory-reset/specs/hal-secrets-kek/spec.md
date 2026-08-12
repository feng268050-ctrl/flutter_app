## MODIFIED Requirements

### Requirement: OP-TEE seal KEK persists via HUK-wrapped Vendor Storage

When `secrets_backend` is `optee`, the seal TA’s AES KEK SHALL be recoverable after A/B rootfs replacement and after factory wipe of userdata/REE TEE FS (including the product **factory-reset** helper deleting `/userdata/tee`), without regenerating the seal KEK itself. The system SHALL persist only a **HUK-bound wrapped** representation of that KEK in Vendor Storage at the ID defined by `vendor-storage-identity`. Plaintext KEK MUST NOT be written to Vendor Storage, REE filesystem paths, or logs. Unwrapping and use of the KEK MUST occur inside the TEE (seal TA). REE FS under the configured tee-supplicant parent (e.g. `/userdata/tee`) MAY cache the KEK for performance but MUST NOT be the sole durable store. Factory-reset MUST NOT delete or rewrite Vendor Storage ID **23**. If HUK-bound wrap is unavailable on the device BL32, the implementation MUST fail closed for persistence bootstrap and MUST NOT store plaintext KEK in Vendor Storage. RPMB (`TEE_STORAGE_PRIVATE_RPMB`) remains optional future work when vendor BL32 enables it; it is not required for this persistence path.

#### Scenario: Round-trip after REE TEE FS wipe

- **WHEN** an OP-TEE seal KEK has been wrapped and stored in Vendor Storage
- **AND** REE TEE FS under the configured parent path is deleted
- **AND** `tee-supplicant` is restarted
- **THEN** seal/unseal of a previously sealed blob with the same AAD still recovers the original plaintext

#### Scenario: Factory-reset deletes REE cache but keeps wrap and cloud key

- **WHEN** factory-reset deletes `/userdata/tee` (or equivalent REE tee-supplicant parent)
- **AND** Vendor Storage ID **23** still holds the HUK-wrapped seal KEK
- **AND** Vendor Storage ID **22** still holds the sealed cloud Ed25519 blob
- **AND** `tee-supplicant` starts after reboot
- **THEN** the seal KEK is recoverable from Vendor Storage
- **AND** ID **23** was not cleared by factory-reset
- **AND** unseal of ID **22** with the same AAD still recovers the activated cloud private-key seed (no re-activation)

#### Scenario: Cloud Ed25519 seed unchanged across KEK migrate

- **WHEN** a device has a Vendor Storage ID 22 cloud Ed25519 sealed blob unsealable under the current KEK
- **AND** the operator migrates the seal KEK into the HUK-wrapped Vendor Storage form
- **THEN** unseal of ID 22 with the same AAD yields the same private-key seed as before migrate
- **AND** the implementation MUST NOT generate a new Ed25519 keypair as part of KEK migrate

#### Scenario: Plaintext KEK forbidden in Vendor Storage

- **WHEN** inspecting the Vendor Storage item for the wrapped seal KEK
- **THEN** the value MUST be the opaque wrap blob (magic/version/nonce/tag/ciphertext) only
- **AND** MUST NOT be the raw 32-byte AES KEK
