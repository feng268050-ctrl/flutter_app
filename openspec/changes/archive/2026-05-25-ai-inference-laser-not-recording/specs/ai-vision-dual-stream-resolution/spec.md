## MODIFIED Requirements

### Requirement: Dual-stream role separation for recording and live inference

When IPC supports multiple RTSP streams, the system SHALL use a high-quality **main** stream for recording and a separate stream for live inference. In AI Vision monitor mode, live preview MAY share the inference stream. In Quick Mode and Engineer Mode, recording SHALL bind to the main stream (typically `/PR0`) and weld-time inference SHALL bind to the sub stream (typically `/PR1`), with independent start/stop lifecycles.

#### Scenario: IPC supports main and sub stream
- **WHEN** AI Vision enters live mode and stream capability check reports sub-stream available
- **THEN** recording SHALL bind to the configured 1920x1080 profile (main stream)
- **AND** live preview/inference SHALL bind to the configured sub-stream profile (e.g. field reference **640×512** or **1280×720**, per IPC settings)

#### Scenario: Quick or Engineer mode with laser on
- **WHEN** Quick Mode or Engineer Mode reports laser ON on a camera with main and sub streams
- **THEN** inference SHALL bind to the sub-stream URL without requiring recording to be active
- **AND** recording when started SHALL bind only to the main-stream URL and SHALL NOT be the only path that supplies inference frames

## ADDED Requirements

### Requirement: Production recording does not subsume inference stream role

In Quick Mode and Engineer Mode, main-stream recording SHALL NOT be the only RTSP session that feeds `LensGuardManager` during welding.

#### Scenario: Record stop while laser still on
- **WHEN** the user stops video recording while laser remains ON
- **THEN** sub-stream inference SHALL continue until laser turns OFF
- **AND** main-stream recording client SHALL release without stopping the inference client
