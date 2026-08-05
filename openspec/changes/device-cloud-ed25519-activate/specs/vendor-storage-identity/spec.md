## ADDED Requirements

### Requirement: Vendor Storage ID for sealed cloud Ed25519 private key

The Vendor Storage ID map SHALL include a frozen product custom ID for the **sealed** cloud Ed25519 private-key blob: decimal ID **22** (`VENDOR_CUSTOM_ID_16`). The repository source of truth (`board/vendor-storage-ids.txt` and the on-device copy under `/usr/libexec/board/`) SHALL document this ID alongside SN/brand/model. The stored value SHALL be the opaque Secrets seal ciphertext (not plaintext key material). Plaintext Ed25519 private keys MUST NOT be written to Vendor Storage. This ID SHALL NOT be repurposed after field freeze without an explicit migration.

#### Scenario: ID map documents cloud key slot

- **WHEN** inspecting `board/vendor-storage-ids.txt` after this change
- **THEN** it SHALL define ID **22** for the sealed cloud Ed25519 private-key blob

#### Scenario: No plaintext private key in Vendor Storage

- **WHEN** the cloud key is persisted
- **THEN** the Vendor Storage item at ID **22** MUST contain Secrets-sealed ciphertext only
