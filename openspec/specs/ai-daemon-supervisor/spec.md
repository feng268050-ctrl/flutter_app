# ai-daemon-supervisor Specification

## Purpose
TBD - created by archiving change ai-cpp-daemon-unix-socket. Update Purpose after archive.
## Requirements
### Requirement: Supervisor owns daemon lifecycle on cold start

The App SHALL provide `AiDaemonSupervisor` (name MAY vary; responsibility MUST NOT) that, at AI cold-start timing aligned with `LaserApplication.initAiEngine`, ensures the socket directory exists, removes stale sock files, spawns `lws_ai_daemon` with workdir/socket argv or env, connects to `cmd.sock`, and subscribes to `evt.sock`. Startup phase logging MUST include `startup_phase=ai_daemon` with `outcome=ok|failed`.

#### Scenario: Successful cold start

- **WHEN** App cold start runs AI initialization
- **THEN** Supervisor MUST spawn the daemon and establish cmd + evt connections
- **AND** MUST log `startup_phase=ai_daemon` with successful outcome when ready

#### Scenario: Spawn failure is non-fatal to other startup

- **WHEN** daemon binary is missing or fails to start
- **THEN** Supervisor MUST record failure outcome and `daemon_state=error` (or equivalent)
- **AND** MUST NOT crash the App process solely due to this failure

### Requirement: Supervisor restarts crashed daemon with backoff

If the daemon process exits or heartbeats/`ping` fail beyond the configured timeout, Supervisor MUST attempt recovery: SIGTERM, then SIGKILL after timeout, unlink stale socks, respawn, reconnect, and re-push last known `laser_state` and `ai_assist_config` (and later session config/start when those exist). Restart attempts MUST use exponential backoff with an upper bound to avoid CPU spin; after the cap, Supervisor MUST enter an error state until manual recovery or next cold start clears the counter.

#### Scenario: Kill child triggers restart

- **WHEN** an operator kills `lws_ai_daemon` while the App remains running
- **THEN** Supervisor MUST detect the death within the watchdog window
- **AND** MUST spawn a new daemon and re-push laser + AI assist state after reconnect

#### Scenario: Continuous crash hits backoff cap

- **WHEN** the daemon crashes repeatedly beyond the configured attempt budget
- **THEN** Supervisor MUST stop tight respawn loops
- **AND** MUST leave a durable error indication for diagnostics

### Requirement: Supervisor pushes laser Bit0 and AI assist settings

Supervisor SHALL observe `DeviceStatus` laser Bit0 (`isLaserOn()`) and `AiAssistanceSettings` toggles. On edge changes, it MUST immediately send the corresponding cmd. After every successful (re)connect, it MUST push a full snapshot of both.

#### Scenario: Bit0 edge pushes laser_state

- **WHEN** Modbus-backed Bit0 transitions from off to on
- **THEN** Supervisor MUST send `laser_state` with `laser_on:true` without waiting for the next periodic timer alone

#### Scenario: Settings change pushes ai_assist_config

- **WHEN** the user disables lens contamination detection in advanced settings
- **THEN** Supervisor MUST send `ai_assist_config` with `lens_contamination_enabled:false`

### Requirement: Supervisor stops daemon on App terminate

On App terminate / `AiManager.stop`-aligned cleanup, Supervisor MUST request daemon shutdown (or kill if needed) and remove sock files under `{files}/ai_daemon/`.

#### Scenario: Terminate cleans sockets

- **WHEN** the App tears down the AI engine for process exit
- **THEN** `lws_ai_daemon` MUST not remain running as an orphan from that App instance
- **AND** `cmd.sock` / `evt.sock` MUST be removed or left non-listening

### Requirement: Result subscription fans out to Java consumers

Supervisor (or its evt reader) SHALL deserialize evt JSON Lines and fan out detect/pipeline events into the existing Java result path (`StreamDetectResultBus` or adapter) once P1 publishes those types, so alerts/upload/UI remain subscriber-based.

#### Scenario: P0 only lifecycle events

- **WHEN** only P0 is implemented
- **THEN** Supervisor MUST at least consume `daemon_ready` and `heartbeat` for health
- **AND** MAY no-op unknown detect types until P1 wiring lands

#### Scenario: P1 detect_result reaches bus

- **WHEN** P1 is active and daemon publishes `detect_result`
- **THEN** registered `StreamDetectResultBus` subscribers MUST receive an equivalent dispatch to today's JNI uplink path

