# host-reset-process-library Specification

## Purpose

Host Make/SSH helper `make reset-process-library`: clear on-device process-library DB and force-reimport bundled assets via a `/run/hmi` command watcher without restarting HMI.

## Requirements

### Requirement: Host make reset-process-library clears DB without restarting HMI

The repository SHALL provide a host helper named `make reset-process-library` (lws-ui naming parity) that connects to the selected board using the same device selection rules as other host SSH helpers and triggers an in-app process-library reset **without** stopping or restarting `hmi.service`.

#### Scenario: Operator resets process library

- **WHEN** the operator runs `make reset-process-library` on a reachable board with HMI running
- **THEN** the helper SHALL write `/run/hmi/reset-process-library.cmd` with a `reset` command
- **AND** the running HMI SHALL delete all rows from `process_presets` and `process_library_meta` (including user presets)
- **AND** the running HMI SHALL force-reimport the bundled process library
- **AND** the helper SHALL NOT restart `hmi.service`

#### Scenario: HMI must be running

- **WHEN** HMI is not running (no command watcher)
- **THEN** the host helper still writes the command file
- **AND** the reset takes effect only after HMI starts and consumes the file (or the operator re-runs after HMI is up)

### Requirement: Reset helper is documented like other host cmd helpers

Makefile `help`, README Make commands, and AGENTS.md SHALL document `make reset-process-library` as a host-only operator helper (no firmware rebuild), describing that it clears process-library DB state via the running HMI watcher and force-reimports bundled assets without restarting HMI (same pattern as `upgrade-process-library`).

#### Scenario: Help lists the target

- **WHEN** an operator runs `make help`
- **THEN** the output SHALL include `reset-process-library` with a short description of clear-DB + bundled re-import without HMI restart
