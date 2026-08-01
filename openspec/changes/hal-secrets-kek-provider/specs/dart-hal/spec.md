## ADDED Requirements

### Requirement: Board bindings expose Secrets provider

`BoardBindings` (or equivalent board profile construction) SHALL construct the abstract Secrets / KEK provider for the Linux appliance with **hardware OP-TEE as the default on real-board profiles**, and software fallback only for emulator/sim (or other profiles where hardware TEE is unavailable). Product App code that only needs Wi‑Fi MUST NOT be required to import the Secrets module; Wi‑Fi HAL internals MAY use Secrets without exposing it as a required App import.

#### Scenario: Real board prefers OP-TEE

- **WHEN** bindings construct Secrets for a ynh960-class product profile
- **THEN** the selected backend is OP-TEE-backed when TEE is available

#### Scenario: Sim profile may use software fallback

- **WHEN** bindings construct Secrets for an emulator/sim profile without TEE
- **THEN** the selected backend MAY be the software fallback
- **AND** the concrete TEE client type is not required in product App imports for Wi‑Fi-only UI
