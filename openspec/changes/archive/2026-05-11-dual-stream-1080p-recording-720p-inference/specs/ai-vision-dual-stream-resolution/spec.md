## ADDED Requirements

### Requirement: Dual-stream role separation for recording and live inference

When IPC supports multiple RTSP streams, the system SHALL use a high-quality stream for recording and a lower-latency stream for live AI Vision preview and inference.

#### Scenario: IPC supports main and sub stream
- **WHEN** AI Vision enters live mode and stream capability check reports sub-stream available
- **THEN** recording SHALL bind to the configured 1920x1080 profile (main stream)
- **AND** live preview/inference SHALL bind to the configured sub-stream profile (e.g. field reference **640×512** or **1280×720**, per IPC settings)

### Requirement: Deterministic fallback when sub-stream is unavailable

The system SHALL provide deterministic fallback behavior when sub-stream is unsupported or unreachable, and SHALL log the fallback reason.

#### Scenario: Sub-stream unavailable
- **WHEN** sub-stream URL fails capability check or connection
- **THEN** the system SHALL switch to single-stream mode according to configured fallback policy
- **AND** the fallback reason and selected stream profile SHALL be emitted to diagnostics logs

### Requirement: Stream profile observability

The system SHALL expose runtime observability for selected stream profile and effective decode resolution.

#### Scenario: Live stream starts successfully
- **WHEN** the first frame is displayed
- **THEN** logs SHALL include selected profile (main/sub/fallback), RTSP URL identity (masked host allowed), decode type, and effective video size
