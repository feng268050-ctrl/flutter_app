# cyber-pm Specification

## Purpose
TBD - created by archiving change app-owned-mediamtx-cyber-pm. Update Purpose after archive.
## Requirements
### Requirement: cyber_pm provides ProcessSupervisor

The repository SHALL provide a Dart path package `packages/cyber_pm` that exports a `ProcessSupervisor` capable of starting a child process with configurable executable, arguments, working directory, and environment; stopping it; reporting whether it is running; and draining merged stdout/stderr line-by-line through an injectable log sink with a stable log prefix. The package MUST NOT depend on `cyber_hal` or product MediaMTX/AI types.

#### Scenario: Start and stop

- **WHEN** a consumer calls start with a valid executable then later stop
- **THEN** the child process is spawned and afterward is not left running

#### Scenario: Log drain uses prefix

- **WHEN** the child writes a line to stdout or stderr
- **THEN** the log sink receives a line that includes the configured log prefix

### Requirement: RestartPolicy is pluggable

`cyber_pm` SHALL provide restart policies including at least `none` and `onFailure` with a configurable delay (and optional max burst). When `onFailure` is selected and the child exits while supervision is wanted, the supervisor MUST attempt to respawn according to the policy.

#### Scenario: onFailure respawn

- **WHEN** restart policy is onFailure and the supervised child exits unexpectedly while start was requested
- **THEN** the supervisor respawns the child after the configured delay (until stop or burst cap if set)

### Requirement: Process factory is injectable for tests

Process creation SHALL be injectable so package unit tests can exercise supervisor logic without spawning real binaries.

#### Scenario: Fake process in unit test

- **WHEN** a unit test injects a fake process factory
- **THEN** start/stop/restart behavior can be asserted without requiring a board or real MediaMTX binary

