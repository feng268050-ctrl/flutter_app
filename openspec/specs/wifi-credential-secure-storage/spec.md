# wifi-credential-secure-storage Specification

## Purpose
Encrypted Wi‑Fi credential vault (scheme 2): PSKs sealed via HAL Secrets, `mem_only_psk` inject into wpa, migration from plaintext conf. Does not own OP-TEE/KEK backends (`hal-secrets-kek`).

## Requirements
### Requirement: Wi-Fi PSK at rest uses an encrypted credential vault

The system SHALL store Wi‑Fi operator passphrases / PSKs in an encrypted credential vault under the wpa userdata tree (e.g. `/var/lib/wpa_supplicant/`). Vault ciphertext SHALL be protected using the HAL Secrets seal/unseal API (`hal-secrets-kek` / change `hal-secrets-kek-provider`). Plaintext PSK MUST NOT remain in `wpa_supplicant.conf` after save or migration.

#### Scenario: Connect stores secret in vault not conf

- **WHEN** the operator connects to a PSK-protected SSID with a passphrase
- **AND** configuration is persisted
- **THEN** the passphrase or PSK is present in the encrypted vault for that SSID
- **AND** `wpa_supplicant.conf` does not contain a plaintext `psk=` or passphrase assignment for that network

#### Scenario: Forget removes vault entry

- **WHEN** the operator forgets SSID `Home`
- **THEN** the wpa configured network for `Home` is removed
- **AND** the vault no longer contains a secret for `Home`

### Requirement: Vault sealing uses HAL Secrets API

The Wi‑Fi credential vault MUST obtain seal/unseal from the abstract HAL Secrets / KEK provider. It MUST NOT embed a separate OP-TEE or software KEK implementation. Backend selection (hardware OP-TEE vs software fallback when TEE unavailable) is owned by `hal-secrets-kek`.

#### Scenario: Vault calls abstract Secrets

- **WHEN** a PSK is stored in the vault
- **THEN** sealing is performed via the HAL Secrets provider
- **AND** the Wi‑Fi module does not construct a concrete Tee client type for that seal

### Requirement: Runtime inject into wpa without persisting PSK in conf

When associating or restoring Auto Join, the Linux Wi‑Fi path SHALL unseal the vault entry for the target SSID and inject the PSK into the wpa network object in memory (D-Bus or equivalent). Saved networks that use a PSK SHALL set `mem_only_psk=1` (or equivalent) so SaveConfig does not write the PSK to the configuration file. PSK material MUST NOT be written to info-level logs.

#### Scenario: selectSaved injects from vault

- **WHEN** SSID `Office` is saved in the vault and in wpa configuration
- **AND** `selectSaved("Office")` is invoked
- **THEN** the PSK is injected into the wpa network for association
- **AND** a subsequent SaveConfig leaves no plaintext `psk=` for `Office` in the conf file

#### Scenario: Boot restore injects for Auto Join

- **WHEN** the wpa stack starts and the vault contains secrets for Auto Join–enabled saved networks
- **THEN** those PSKs are injected into memory before or during association attempts
- **AND** the operator is not required to re-enter the passphrase solely due to reboot

### Requirement: Plaintext conf credentials are migrated once

On upgrade or first run after this capability is enabled, if `wpa_supplicant.conf` still contains plaintext PSK or passphrase entries, the system SHALL import them into the vault (via Secrets seal), enable mem-only PSK behavior for those networks, and remove the plaintext secrets from the conf file.

#### Scenario: Legacy psk line migrated

- **WHEN** conf contains a network `Home` with a plaintext `psk=` value
- **AND** migration runs
- **THEN** vault contains a secret for `Home`
- **AND** the plaintext `psk=` line for `Home` is removed from conf

### Requirement: Wi-Fi notes defer KEK policy to Secrets change

Wi‑Fi vault security notes SHALL reference `hal-secrets-kek-provider` for hardware-first KEK policy and SHALL NOT claim that Wi‑Fi vault alone completes RED / EN 18031 presumption.

#### Scenario: Notes cross-link Secrets change

- **WHEN** an implementer reads Wi‑Fi vault security notes
- **THEN** they are directed to the Secrets/KEK change for OP-TEE vs emulator software-fallback policy
