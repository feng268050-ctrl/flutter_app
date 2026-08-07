## ADDED Requirements

### Requirement: Vendor Storage ID for HUK-wrapped seal KEK

The Vendor Storage ID map SHALL include a frozen product custom ID for the **HUK-wrapped** OP-TEE seal KEK blob: decimal ID **23** (`VENDOR_CUSTOM_ID_17`). The repository source of truth (`board/vendor-storage-ids.txt` and the on-device copy under `/usr/libexec/board/`) SHALL document this ID alongside SN/brand/model and cloud Ed25519 ID 22. The stored value SHALL be the opaque wrap ciphertext defined by `hal-secrets-kek` (not plaintext KEK). Plaintext seal KEKs MUST NOT be written to Vendor Storage. This ID SHALL NOT be repurposed after field freeze without an explicit migration.

#### Scenario: ID map documents wrapped seal KEK slot

- **WHEN** inspecting `board/vendor-storage-ids.txt` after this change
- **THEN** it SHALL define ID **23** for the HUK-wrapped seal KEK blob

#### Scenario: No plaintext KEK in Vendor Storage

- **WHEN** the seal KEK persistence material is written
- **THEN** the Vendor Storage item at ID **23** MUST contain the opaque wrap blob only

### Requirement: On-board helpers for wrapped seal KEK

The appliance rootfs SHALL provide thin board helpers under `/usr/libexec/board/` to read and write Vendor Storage ID **23** (names parallel to cloud Ed25519 sealed helpers). Helpers SHALL fail clearly when `/dev/vendor_storage` is unavailable (e.g. emulator). Operator or HMI migrate paths MAY invoke these helpers (`make migrate-seal-kek` / `secrets-seal sync-kek`); Apps MUST NOT embed raw Vendor Storage ioctls for this ID.

#### Scenario: Helpers present on product image

- **WHEN** a product image with this change is inspected
- **THEN** read/write helpers for the wrapped seal KEK ID SHALL exist under `/usr/libexec/board/`
