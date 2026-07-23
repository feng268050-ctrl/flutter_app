## ADDED Requirements

### Requirement: Zero-point on-laser sampling interval

The system SHALL define **`AiFrameSamplingInterval.ZERO_POINT_ON_LASER`** with interval **500 ms** for the laser-triggered zero-point detect task. This interval SHALL match the 500 ms grid used by `AI_VISION_LIVE` and `AI_VISION_PROCESS_VIDEO` but SHALL use a **separate gate or scheduler instance** so zero-point sampling does not share last-accept timestamps with AI Vision live preview or production weld gates.

#### Scenario: Named constant exists

- **WHEN** the App enumerates `AiFrameSamplingInterval`
- **THEN** `ZERO_POINT_ON_LASER` SHALL be present with `getIntervalMs() == 500L`

#### Scenario: Independent gate lifecycle

- **WHEN** a zero-point task completes or is cancelled
- **THEN** any zero-point-specific sampling state SHALL reset
- **AND** production (`PRODUCTION_WELD`) and AI Vision live gates SHALL remain unaffected

## MODIFIED Requirements

### Requirement: Standard frame sampling intervals

The system SHALL define named intervals in `AiFrameSamplingInterval` (code constants; not user-configurable):

| Constant | Interval | Use case |
|----------|----------|----------|
| `PRODUCTION_WELD` | 2000 ms | Quick Mode and Engineer Mode sub-stream live inference |
| `AI_VISION_LIVE` | 500 ms | AI Vision live preview inference from TextureView |
| `AI_VISION_PROCESS_VIDEO` | 500 ms | AI Vision selected process video inference |
| `ZERO_POINT_ON_LASER` | 500 ms | Laser-on zero-point detect task (scheduled samples) |

#### Scenario: Production interval

- **WHEN** live inference runs for Quick Mode or Engineer Mode with laser ON
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.PRODUCTION_WELD` (2000 ms)

#### Scenario: AI Vision live interval

- **WHEN** AI Vision live preview inference is active
- **THEN** the effective sample interval SHALL be `AiFrameSamplingInterval.AI_VISION_LIVE` (500 ms)

#### Scenario: Zero-point on-laser interval

- **WHEN** the laser-on zero-point detect task schedules samples
- **THEN** sample spacing SHALL follow `AiFrameSamplingInterval.ZERO_POINT_ON_LASER` (500 ms) from the first sample at `T₀ + 500ms`
