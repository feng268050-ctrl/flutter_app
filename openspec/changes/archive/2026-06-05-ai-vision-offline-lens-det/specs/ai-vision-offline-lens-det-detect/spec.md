## ADDED Requirements

### Requirement: Process video offline runs lens_det one-shot per 500 ms sample

When `BuildConfig.ENABLE_LENS_DET_APP` is true and the user starts **Detect** on a process video, the system SHALL invoke `AiManager.inferLensDetFromI420` at most once per accepted `AI_VISION_PROCESS_VIDEO` sample, using the same I420 buffer as RKNN stain inference for that sample. The App MUST NOT invoke `inferZeroPointFromI420` on the process video path.

#### Scenario: Same grid as RKNN

- **WHEN** the playback clock schedules a sample at `sampleMs` on the 500 ms grid
- **THEN** lens_det MAY run for that sample after gate acceptance
- **AND** MUST NOT run a second lens_det for the same `sampleMs` in the same session

#### Scenario: Feature off

- **WHEN** `ENABLE_LENS_DET_APP` is false
- **THEN** no lens_det calls and no `lensDet` timeline fields SHALL be written

### Requirement: Process video lens_det uses independent 500 ms gate

The system SHALL gate process-video lens_det with `tryAcceptLensDetProcessVideoInferSample()` backed by `AiFrameSamplingInterval.AI_VISION_PROCESS_VIDEO`. The gate MUST be independent from RKNN and production lens_det gates.

#### Scenario: Reset on session lifecycle

- **WHEN** `ProcessVideoAiSession.start()` runs
- **THEN** `AiManager.resetLensDetProcessVideoFrameSampling()` MUST be called before scheduling samples
- **WHEN** `ProcessVideoAiSession.stop()` completes
- **THEN** `resetLensDetProcessVideoFrameSampling()` MUST be called again

### Requirement: Timeline persists lens_det per sample

Each `ProcessVideoAiTimeline.Frame` for a successful RKNN sample SHALL include an optional `lensDet` object when lens_det ran for that `timeMs`, containing `success`, `code`, `targetX`, `targetY`, and `source`. `ProcessVideoAiTimelinePersistence` MUST round-trip these fields. `GET /v1/videos/:id/ai/replay` SHOULD expose the same fields under each frame.

#### Scenario: Replay after session end

- **WHEN** Detect completes and timeline JSON is saved
- **AND** the user replays the recording without an active session
- **THEN** overlay or HTTP replay MUST be able to read lens_det targets from persisted frames

### Requirement: SSE running includes optional lensDet

`AiInferenceSseJson.runningData` for process video SHALL include a `lensDet` JSON object when a lens_det result exists for that publish, with `success`, `code`, `targetX`, `targetY`, and `source`.

#### Scenario: LAN client ignores unknown fields

- **WHEN** a subscriber receives `running` with `lensDet`
- **THEN** clients that only parse stain fields MUST continue to work

### Requirement: No zero correction from offline lens_det

Offline lens_det MUST NOT write Modbus, Room `zeroPointCorrection`, or `ZeroPointCorrectionWriter`. Production zero point (`ZeroPointDetectCoordinator`) is unchanged.

#### Scenario: Detect only records geometry

- **WHEN** lens_det reports a target at `(x,y)`
- **THEN** Advanced Settings zero point correction MUST remain unchanged by this session
