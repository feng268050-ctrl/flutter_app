## ADDED Requirements

### Requirement: Control plane uses Unix sockets under /run/hmi/ai

On Linux appliances, `lws_ai_daemon` SHALL listen on Unix domain sockets at `/run/hmi/ai/cmd.sock` (request/response) and `/run/hmi/ai/evt.sock` (publish) unless overridden by argv/env at spawn. The control plane MUST NOT bind TCP for this IPC.

#### Scenario: Default socket paths

- **WHEN** the daemon starts with Linux App-owned defaults
- **THEN** it MUST listen on `/run/hmi/ai/cmd.sock` and `/run/hmi/ai/evt.sock`

### Requirement: daemon_ready and ping for P3.3 smoke

After sockets are listening, the daemon SHALL publish a `daemon_ready` event on `evt.sock`. The cmd channel SHALL support a `ping` request that returns a successful `pong` (or equivalent success response) so the App Supervisor can complete smoke verification. Full laser/AI-assist/session command surface MAY be incomplete in this slice and is not required for P3.3 acceptance.

#### Scenario: Ready then ping

- **WHEN** the daemon has accepted its control sockets
- **THEN** it MUST publish a JSON Lines event with type `daemon_ready`
- **AND WHEN** the App sends `ping` on `cmd.sock`
- **THEN** it MUST receive a successful pong/response without crashing the daemon
