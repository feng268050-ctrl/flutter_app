## ADDED Requirements

### Requirement: Configurable frame-sampling gate before LensGuard push

The system SHALL provide a reusable frame-sampling gate that accepts frames into the LensGuard live push path (`guardedPushFrame` via I420 or bitmap conversion) at most once per configured `sampleIntervalMs`, measured on a monotonic clock.

#### Scenario: First frame after reset is accepted immediately

- **WHEN** the gate is reset and a frame arrives
- **THEN** the gate SHALL accept the frame
- **AND** SHALL record the accept timestamp for subsequent intervals

#### Scenario: Frame within interval is rejected

- **WHEN** a frame arrives less than `sampleIntervalMs` after the last accepted frame
- **THEN** the gate SHALL reject the frame
- **AND** SHALL NOT enqueue LensGuard-I420 work for that frame on the production I420 path

#### Scenario: Frame after interval is accepted

- **WHEN** a frame arrives at or after `sampleIntervalMs` since the last accepted frame
- **THEN** the gate SHALL accept the frame
- **AND** SHALL update the last-accept timestamp

### Requirement: Standard inference sample profiles

The system SHALL define named sample profiles with fixed default intervals:

| Profile | Default interval | Use case |
|---------|------------------|----------|
| `PRODUCTION_WELD` | 2000 ms | Quick Mode and Engineer Mode sub-stream live inference |
| `AI_VISION_LIVE` | 500 ms | AI Vision live preview inference from TextureView |

#### Scenario: Production profile interval

- **WHEN** live inference runs for Quick Mode or Engineer Mode with laser ON
- **THEN** the effective sample interval SHALL be the `PRODUCTION_WELD` code constant (2000 ms)

#### Scenario: AI Vision live profile interval

- **WHEN** AI Vision live preview inference is active
- **THEN** the effective sample interval SHALL be the `AI_VISION_LIVE` code constant (500 ms)

### Requirement: Gate reset on stream lifecycle boundaries

The system SHALL reset the sampling gate when the corresponding inference input stops or restarts so the first frame after restart is not delayed by a stale timestamp.

#### Scenario: Production inference stream stops

- **WHEN** the sub-stream inference client stops (laser OFF, release, or coordinator disable)
- **THEN** the production sampling gate SHALL reset

#### Scenario: AI Vision live sampling stops

- **WHEN** AI Vision stops live frame sampling (`stopAiFrameSampling` or fragment inactive)
- **THEN** the AI Vision live sampling gate SHALL reset
