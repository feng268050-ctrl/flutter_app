# ai-cpp-daemon Specification

## Purpose
TBD - created by archiving change ai-cpp-daemon-unix-socket. Update Purpose after archive.
## Requirements
### Requirement: Daemon binary runs outside the App process

The system SHALL provide a native executable named `lws_ai_daemon` that hosts AI algorithm/session logic in a process separate from the Android App process. The App MUST be able to spawn this binary as a child (e.g. `ProcessBuilder`) under the application UID without loading AI algorithms solely via in-process JNI for the daemon lifecycle path.

#### Scenario: Cold start spawns daemon process

- **WHEN** the App completes AI engine cold-start initialization with the daemon Supervisor enabled
- **THEN** an `lws_ai_daemon` process MUST be running as a child of the App
- **AND** the App UI process MUST remain alive if the daemon later exits independently

#### Scenario: Daemon crash does not kill App process

- **WHEN** `lws_ai_daemon` terminates abnormally while the App is foregrounded
- **THEN** the App process MUST continue running
- **AND** recovery MUST be delegated to the Java Supervisor restart policy

### Requirement: Daemon workdir and socket paths are under app private storage

`lws_ai_daemon` SHALL use an application-private work directory compatible with existing lens-guard layout (default `{files}/lens_guard/`) and SHALL serve Unix sockets under `{files}/ai_daemon/` with paths `cmd.sock` and `evt.sock` unless overridden by argv/env at spawn time.

#### Scenario: Socket directory prepared before listen

- **WHEN** the daemon starts with default paths
- **THEN** it MUST listen on `{files}/ai_daemon/cmd.sock` and `{files}/ai_daemon/evt.sock`
- **AND** MUST NOT bind TCP sockets for this control plane

### Requirement: Daemon announces readiness and heartbeats

After sockets are listening, the daemon SHALL publish `daemon_ready` on `evt.sock` and SHALL periodically publish `heartbeat` events so the Supervisor can detect liveness. The daemon MUST remain resident while the App Supervises it and MUST NOT exit solely because laser Bit0 is false.

#### Scenario: Ready event after listen

- **WHEN** the daemon successfully accepts its control sockets
- **THEN** it MUST publish a JSON Lines event with `type` `daemon_ready` and `v` `1`

#### Scenario: Heartbeat while idle

- **WHEN** the daemon is running with no active StreamDetect session
- **THEN** it MUST continue publishing `heartbeat` events at the configured interval
- **AND** MUST remain running until `shutdown` or process kill

### Requirement: Daemon accepts shutdown command

The daemon SHALL honor a cmd `shutdown` (or equivalent ack'd request) by stopping listeners and exiting with a non-crash code so App terminate paths can cleanly stop the child.

#### Scenario: Graceful shutdown

- **WHEN** Java sends `type` `shutdown` on `cmd.sock`
- **THEN** the daemon MUST acknowledge the request
- **AND** MUST exit without requiring SIGKILL under normal conditions

### Requirement: Package distributes daemon for device install

The native/Android packaging path SHALL include `lws_ai_daemon` (and any dynamically linked runtime `.so` dependencies required to exec it) so an installed APK can launch the binary on arm64 device/emulator targets used by product.

#### Scenario: make sync / APK contains daemon

- **WHEN** a release or debug APK is built with AI native packaging enabled
- **THEN** `lws_ai_daemon` MUST be present on the installable artifact path used by Supervisor spawn
- **AND** the binary MUST have execute permission after extract/install as required by the target OS policy

