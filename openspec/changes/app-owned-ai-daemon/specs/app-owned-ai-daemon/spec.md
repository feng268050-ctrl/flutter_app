## ADDED Requirements

### Requirement: Daemon ships under /opt/hmi via build-app

Product packaging SHALL install `lws_ai_daemon` at `/opt/hmi/bin/lws_ai_daemon` and any required companion libraries under `/opt/hmi/lib/` during `make build-app` / HMI bundle install (from `prebuilt/ai/linux-arm64/`). The binary MUST NOT be installed into the shared rootfs overlay as `/usr/bin/lws_ai_daemon`, and the product MUST NOT ship an `ai.service` systemd unit for this daemon.

#### Scenario: Bundle install places binary

- **WHEN** `make build-app` runs with a valid AI prebuilt stamp
- **THEN** the staged HMI tree contains `bin/lws_ai_daemon` with execute permission
- **AND** MUST NOT add `mediamtx`-style rootfs overlay paths for the AI daemon under `/usr/bin`

#### Scenario: Missing prebuilt fails or skips clearly

- **WHEN** AI prebuilt is missing at bundle time
- **THEN** the build MUST either fail with a message to run `make build-ai`, or skip AI install with an explicit log line (implementation MUST pick one consistent policy and document it — prefer fail when AI is part of the product release gate)

### Requirement: App supervises daemon with cyber_pm

The HMI App SHALL provide an `AiDaemonSupervisor` (name MAY vary; responsibility MUST NOT) that uses `packages/cyber_pm` to spawn `/opt/hmi/bin/lws_ai_daemon` as a child process with a failure restart policy. Spawn MUST prepare `/run/hmi/ai/` for sockets and `/var/lib/hmi/ai/` as workdir (or equivalent argv overrides). Missing binary at runtime MUST be non-fatal to App startup (record error; do not crash the UI process).

#### Scenario: Cold start spawns child

- **WHEN** Linux App initialization runs AI daemon smoke start and the binary exists
- **THEN** a `lws_ai_daemon` child MUST be running under the HMI process tree
- **AND** supervision MUST use `cyber_pm` rather than `systemctl`

#### Scenario: Missing binary does not crash App

- **WHEN** `/opt/hmi/bin/lws_ai_daemon` is absent
- **THEN** Supervisor MUST record failure and leave the App running

### Requirement: No rootfs AI boot unit

The shared Buildroot image SHALL NOT enable a systemd wants link for an AI daemon unit, and boot/env verify scripts MUST NOT require a rootfs `ai.service` or `/usr/bin/lws_ai_daemon`.

#### Scenario: Rootfs has no AI unit

- **WHEN** operators inspect a product rootfs after this change
- **THEN** `/usr/bin/lws_ai_daemon` MUST be absent
- **AND** no `ai.service` unit MUST be present in the overlay
