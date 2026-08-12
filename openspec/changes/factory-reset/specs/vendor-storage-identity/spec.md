## ADDED Requirements

### Requirement: Factory reset preserves cloud Ed25519 and product identity

Software **factory-reset** and the compliant factory-flash operator-prefs wipe MUST **preserve** Vendor Storage ID **22** (sealed cloud Ed25519 private-key blob). An activated device MUST remain cloud-activated after factory reset without requiring a new key provisioning or re-registration solely due to the reset. They MUST also preserve Vendor Storage IDs **1** / **20** / **21** (SN / brand / model) and ID **23** (HUK-wrapped seal KEK). Factory-reset MUST NOT clear, overwrite, or rotate ID **22**.

#### Scenario: Cloud slot intact after reset

- **WHEN** ID **22** holds a sealed cloud Ed25519 blob for an activated device
- **AND** factory-reset completes
- **THEN** a subsequent read of ID **22** SHALL return the same sealed blob
- **AND** IDs **1** / **20** / **21** still return the prior brand, model, and SN
- **AND** the device MUST NOT require cloud re-activation solely because factory-reset ran

#### Scenario: Seal KEK wrap untouched by reset

- **WHEN** ID **23** holds a HUK-wrapped seal KEK before factory-reset
- **AND** factory-reset completes
- **THEN** ID **23** still holds the same wrap blob

## MODIFIED Requirements

### Requirement: Vendor Storage ID for sealed cloud Ed25519 private key

The Vendor Storage ID map SHALL include a frozen product custom ID for the **sealed** cloud Ed25519 private-key blob: decimal ID **22** (`VENDOR_CUSTOM_ID_16`). The repository source of truth (`board/vendor-storage-ids.txt` and the on-device copy under `/usr/libexec/board/`) SHALL document this ID alongside SN/brand/model. The stored value SHALL be the opaque Secrets seal ciphertext (not plaintext key material). Plaintext Ed25519 private keys MUST NOT be written to Vendor Storage. This ID SHALL NOT be repurposed after field freeze without an explicit migration. **Factory-reset**, compliant factory-flash operator-prefs wipe, A/B upgrade, and OTA MUST all **preserve** this ID (activated cloud identity survives operator data wipe).

#### Scenario: ID map documents cloud key slot

- **WHEN** inspecting `board/vendor-storage-ids.txt` after this change
- **THEN** it SHALL define ID **22** for the sealed cloud Ed25519 private-key blob

#### Scenario: No plaintext private key in Vendor Storage

- **WHEN** the cloud key is persisted
- **THEN** the Vendor Storage item at ID **22** MUST contain Secrets-sealed ciphertext only

#### Scenario: Upgrade leaves cloud key intact

- **WHEN** ID **22** holds a sealed blob and a full-system upgrade completes
- **THEN** ID **22** remains present and readable as sealed ciphertext

#### Scenario: Factory-reset leaves cloud key intact

- **WHEN** ID **22** holds a sealed blob and factory-reset completes
- **THEN** ID **22** remains present and readable as sealed ciphertext
