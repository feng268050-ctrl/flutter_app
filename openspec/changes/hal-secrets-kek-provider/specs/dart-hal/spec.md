## ADDED Requirements

### Requirement: Board bindings expose Secrets provider

`BoardBindings` (or equivalent board profile construction) SHALL be able to construct the abstract Secrets / KEK provider for the Linux appliance according to board profile configuration (OP-TEE-backed or interim software). Product App code that only needs Wi‑Fi MUST NOT be required to import the Secrets module; Wi‑Fi HAL internals MAY use Secrets without exposing it as a required App import.

#### Scenario: Bindings can construct Secrets

- **WHEN** board profile selects a Secrets backend
- **THEN** bindings can construct a Secrets provider implementing seal/unseal
- **AND** the concrete TEE client type is not required in product App imports for Wi‑Fi-only UI
