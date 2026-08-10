# app-owned-ai-daemon Specification

## Purpose

Product packaging and App supervision for `lws_ai_daemon`: ship under `/opt/hmi`, supervise via `cyber_pm`, and keep the shared rootfs free of an AI systemd unit.

## Requirements

### Requirement: Daemon ships under /opt/hmi via build-app

Product packaging SHALL install `lws_ai_daemon` at `/opt/hmi/bin/lws_ai_daemon` and App-owned companion libraries (e.g. OpenCV) under `/opt/hmi/lib/` during `make build-app` / HMI bundle install when an executable daemon is present at `prebuilt/ai/linux-arm64/lws_ai_daemon` (companions from that tree’s `lib/` as applicable). Packaging MUST NOT require a `.lws-prebuilt` stamp under the AI prebuilt directory. The product MUST NOT install `librknnrt.so` under `/opt/hmi/lib/`; the daemon SHALL load the system RKNN runtime from `/usr/lib/librknnrt.so` (provided by `fetch-rknn-rt` / rootfs). The binary MUST NOT be installed into the shared rootfs overlay as `/usr/bin/lws_ai_daemon`, and the product MUST NOT ship an `ai.service` systemd unit for this daemon.

#### Scenario: Bundle install places binary when daemon prebuilt exists

- **WHEN** `make build-app` runs and `prebuilt/ai/linux-arm64/lws_ai_daemon` is executable
- **THEN** the staged HMI tree contains `bin/lws_ai_daemon` with execute permission
- **AND** MUST NOT add `mediamtx`-style rootfs overlay paths for the AI daemon under `/usr/bin`
- **AND** MUST NOT place `lib/librknnrt.so` under the staged `/opt/hmi` tree
- **AND** MUST NOT require `prebuilt/ai/linux-arm64/.lws-prebuilt` to be present

#### Scenario: Missing daemon fails or skips clearly

- **WHEN** the AI daemon binary is missing at bundle time
- **THEN** the build MUST either fail with a message to run `make build-ai` (when `REQUIRE_AI=1` or equivalent release gate), or skip AI install with an explicit log line
- **AND** the decision MUST NOT depend on a `.lws-prebuilt` stamp file

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
