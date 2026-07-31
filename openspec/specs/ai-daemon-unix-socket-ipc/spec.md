# ai-daemon-unix-socket-ipc Specification

## Purpose

App-facing unix socket control plane for lws_ai_daemon including StreamDetect commands.

## Requirements

### Requirement: StreamDetect cmd surface for live camera AI

In addition to `ping` / `daemon_ready`, the App-facing control plane SHALL support (via cmd.sock) the StreamDetect and assist commands required for live camera AI: `configure_session`, `stream_detect_start`, `stream_detect_stop`, `laser_state`, and `ai_assist_config`. The App MUST keep an evt.sock subscription for StreamDetect uplink types while the supervisor is started.

#### Scenario: Start after configure

- **WHEN** the App issues a valid `configure_session` followed by `stream_detect_start` with `rtsp_url`
- **THEN** the daemon MUST acknowledge success when the pipeline can start
- **AND** subsequent `session_start` / `detect_result` events MUST appear on evt.sock when sampling runs

#### Scenario: Evt subscription while ready

- **WHEN** `AiDaemonSupervisor` reports ready after smoke ping
- **THEN** the App MUST remain subscribed to evt.sock for StreamDetect event types until stop
