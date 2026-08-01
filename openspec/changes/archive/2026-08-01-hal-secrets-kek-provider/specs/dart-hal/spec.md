## ADDED Requirements

### Requirement: Board bindings expose Secrets provider

`BoardBindings` (or equivalent board profile construction) SHALL construct the abstract Secrets / KEK provider according to OEM `BoardProfile.secretsBackend` (`software` | `optee`), with the unset-field heuristic documented in the Secrets capability (sim/emu → software; other board ids → optee). Product App code that only needs Wi‑Fi MUST NOT be required to import the Secrets module; Wi‑Fi HAL internals MAY use Secrets without exposing it as a required App import.

#### Scenario: ynh960 software profile

- **WHEN** bindings construct Secrets for a ynh960 product profile with `secrets_backend: software`
- **THEN** the selected backend is the device-bound software KEK provider

#### Scenario: Profile flip to OP-TEE

- **WHEN** the same board id profile sets `secrets_backend: optee`
- **THEN** the selected backend is the OP-TEE-backed provider (fail-closed if TEE/TA missing)

#### Scenario: Sim profile may use software

- **WHEN** bindings construct Secrets for an emulator/sim profile without an explicit optee preference
- **THEN** the selected backend MAY be the software fallback
- **AND** the concrete TEE client type is not required in product App imports for Wi‑Fi-only UI
