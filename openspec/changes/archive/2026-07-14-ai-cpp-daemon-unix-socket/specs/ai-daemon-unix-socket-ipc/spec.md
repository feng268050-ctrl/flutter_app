## ADDED Requirements

### Requirement: Dual Unix Domain Socket transport

IPC between Java and `lws_ai_daemon` SHALL use two `AF_UNIX` `SOCK_STREAM` sockets:

- `cmd.sock`: Java is client; daemon is server; request/response
- `evt.sock`: Java is client subscriber; daemon is server publisher

Framing MUST be UTF-8 JSON Lines (one JSON object followed by `\n`). Messages MUST include `v` (protocol version, initially `1`), `type` (string), and `ts_ms`. Cmd requests that expect a matching response MUST include `id`; responses MUST echo the same `id`.

#### Scenario: Ping round-trip

- **WHEN** Java sends `{"v":1,"type":"ping","id":"...","ts_ms":...}` on `cmd.sock`
- **THEN** the daemon MUST reply with an ack (e.g. `ping_ack` or equivalent `ok:true`) carrying the same `id`

#### Scenario: Invalid message returns error

- **WHEN** Java sends a cmd with unknown `type` or malformed JSON
- **THEN** the daemon MUST respond with an error envelope (`ok:false` plus `code`/`message`, or dedicated `error` type) when an `id` is present
- **AND** MUST NOT crash the process

### Requirement: Laser Bit0 state command

Cmd type `laser_state` SHALL carry boolean `laser_on` representing Modbus `machineStatusSeg1` Bit0 (same meaning as `DeviceStatus.isLaserOn()`). This field MUST NOT represent laser enable holder state. The daemon MUST acknowledge with `laser_state_ack` (or error) using the request `id`.

#### Scenario: Laser on acknowledged

- **WHEN** Java sends `laser_state` with `laser_on:true`
- **THEN** the daemon MUST reply with matching `id` and `ok:true`
- **AND** MUST treat subsequent sampling gates as laser-on per the live state machine once StreamDetect is active (P1+)

#### Scenario: Laser off stops sampling not process

- **WHEN** Java sends `laser_state` with `laser_on:false` while the daemon is resident
- **THEN** the daemon MUST acknowledge success
- **AND** MUST NOT exit the process solely due to this update

### Requirement: AI assist config command

Cmd type `ai_assist_config` SHALL carry at least:

- `lens_contamination_enabled`
- `zero_point_offset_enabled`

mapped from Java `AiAssistanceSettings`. The daemon MUST acknowledge and MUST skip corresponding module inference/publish when a flag is false (once detect modules are wired).

#### Scenario: Config push after connect

- **WHEN** Java successfully connects to cmd after daemon restart
- **THEN** Java MUST send a full `ai_assist_config` snapshot
- **AND** the daemon MUST ack the snapshot

### Requirement: Stream detect control commands (target protocol)

The protocol SHALL define cmd types `configure_session`, `stream_detect_start`, `stream_detect_stop`, `stream_detect_burst_mode`, `stream_detect_zp_target_mode`, `offline_infer_opencv_stain_nv12`, `offline_infer_zero_point_nv12`, and `shutdown`, plus room for further `offline_infer_*` types. Implementations MAY stub remaining handlers until the corresponding migration phase, but MUST NOT invent a second competing control schema for the same operations.

#### Scenario: Documented types are stable at v1

- **WHEN** a client speaks protocol `v` `1`
- **THEN** the server MUST recognize the reserved cmd type names listed in the design (`ping`, `laser_state`, `ai_assist_config`, `configure_session`, `stream_detect_start`, `stream_detect_stop`, `stream_detect_burst_mode`, `stream_detect_zp_target_mode`, `offline_infer_opencv_stain_nv12`, `offline_infer_zero_point_nv12`, `shutdown`)
- **AND** unimplemented types MUST return a clear error rather than silently succeeding

#### Scenario: Offline NV12 infer uses shared workdir file path

- **WHEN** Java requests `offline_infer_opencv_stain_nv12` or `offline_infer_zero_point_nv12` with `nv12_path` under the daemon workdir
- **THEN** the daemon MUST read the NV12 file, run the algorithm in-process, and return `summary_json` in the ack
- **AND** MUST NOT require a multi-megabyte base64 frame in the cmd JSON

### Requirement: Event publish types

The daemon SHALL publish JSON Lines events on `evt.sock` with types including at minimum for P0: `heartbeat`, `daemon_ready`, and daemon-level `error`/`health`. For live detect (P1+), events MUST map existing pipeline semantics for `session_start`, `session_stop`, `pipeline_state`, `detect_result`, and `combined_frame`.

#### Scenario: Detect result shape remains Java-friendly

- **WHEN** the daemon publishes `detect_result` for module `lens_det`
- **THEN** the payload MUST include fields usable by today's Java subscribers (module id, frame dimensions/ids as applicable, `code`/`ok`, and summary JSON string or object)
- **AND** MUST NOT include raw YUV/bitmap payloads

### Requirement: Non-blocking evt backpressure

Daemon writers to `evt.sock` MUST use a bounded buffer policy. When the Java subscriber is slow, the daemon MUST prefer dropping or coalescing non-critical events (e.g. duplicate `pipeline_state`, excess heartbeats) over blocking detect/decode threads indefinitely.

#### Scenario: Slow subscriber does not starve decode

- **WHEN** Java stops reading `evt.sock` for longer than the write buffer capacity during active streaming
- **THEN** the daemon MUST apply overflow policy
- **AND** MUST keep the RTSP/decode path from permanently hanging on a full socket write
