## ADDED Requirements

### Requirement: FRAME_REJECTED burst interval for coordinated live detect

The system SHALL define `FRAME_REJECTED_BURST` with interval **100 ms** in `AiFrameSamplingInterval` for coordinated live PR1 detect paths (zero_point + lens_det) when burst sampling mode is active.

#### Scenario: Burst interval constant

- **WHEN** burst sampling mode is active on the live PR1 weld path
- **THEN** participating gates MUST use `FRAME_REJECTED_BURST` (100 ms)

## MODIFIED Requirements

### Requirement: Standard frame sampling intervals

The system SHALL define named intervals in `AiFrameSamplingInterval` (code constants; not user-configurable):

| Constant | Interval | Use case |
|----------|----------|----------|
| `LIVE_WELD` | **500 ms** | Live PR1 sub-stream OpenCV stain detect while welding (Quick / Engineer), **normal mode** |
| `AI_VISION_LIVE` | 500 ms | AI Vision live preview inference from TextureView |
| `AI_VISION_PROCESS_VIDEO` | 200 ms | AI Vision selected process video detect sampling |
| `ZERO_POINT_ON_LASER` | 500 ms | Laser-on zero-point detect (**normal mode**, PR1-driven, continuous while laser ON) |
| `FRAME_REJECTED_BURST` | 100 ms | Live PR1 zero_point + lens_det while burst mode active after `code=-5` |

#### Scenario: Live weld interval in normal mode

- **WHEN** production sub-stream pushes frames during welding in normal sampling mode
- **THEN** the OpenCV stain detect gate SHALL use `LIVE_WELD` (**500 ms**)

#### Scenario: Zero point interval in normal mode

- **WHEN** a laser-on zero-point round accepts PR1-driven samples in normal mode
- **THEN** the zero-point gate SHALL use `ZERO_POINT_ON_LASER` (500 ms) between accepted attempts

#### Scenario: Live weld constant value

- **WHEN** code reads `AiFrameSamplingInterval.LIVE_WELD.getIntervalMs()`
- **THEN** the value SHALL be `500L`
