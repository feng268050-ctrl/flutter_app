## ADDED Requirements

### Requirement: Stain audit status enum SHALL model automated upload eligibility

The system SHALL define `StainAuditStatus` (or equivalent) with at least the values: `CLEAN`, `STAIN_CONFIRMED`, `INTERNAL_FILTERED`, `DETECT_FAILED`, `AUTO_SUSPECTED_MISS`, and `AUTO_SUSPECTED_FALSE_POSITIVE`.

For this change iteration, only `DETECT_FAILED` SHALL trigger automatic `AiUploadCoordinator` enqueue on the Live weld path. All other values SHALL NOT enqueue upload tasks in this iteration.

#### Scenario: Detect failed is upload-eligible

- **WHEN** a Live weld `lens_det` sample is classified as `StainAuditStatus.DETECT_FAILED`
- **THEN** the system SHALL treat the sample as eligible for `AiUploadCoordinator.enqueue`

#### Scenario: Internal filtered is not upload-eligible

- **WHEN** a Live weld `lens_det` sample maps to `INTERNAL_FILTERED` (including native `code == -5` frame rejected)
- **THEN** the system MUST NOT enqueue an ai-report upload task for that sample

#### Scenario: Confirmed stain is not upload-eligible

- **WHEN** a Live weld `lens_det` sample maps to `STAIN_CONFIRMED` (`ok == true`, `code == 0`)
- **THEN** the system MUST NOT enqueue an ai-report upload task for that sample

### Requirement: Live weld DETECT_FAILED SHALL enqueue lens failure upload via AiUploadCoordinator

When `OpencvStainDetectCoordinator` processes a Live weld `StreamDetectResultBus` `lens_det` event with native `code == -3` (`OpencvDetectCodes.DETECT_FAILED`), and `AiAssistanceSettings.isLensContaminationDetectionEnabled()` is true, and `LiveInferGraceCoordinator.isLiveInferActive()` is true, the system SHALL:

1. Resolve a readable JPEG source file for the failed frame (`input_frame.jpg` under the per-frame native output directory).
2. Build a `stat.json` payload documenting `status=DETECT_FAILED`, native `reason`, `source=live_stain_detect`, `created_at`, and `frame_id` when available.
3. Call `AiUploadCoordinator.enqueue` with `model=lens`, `type=0`, the source image file, and the audit stat JSON.

The enqueue SHALL NOT block the detect result callback thread for network I/O.

#### Scenario: Native detect failed triggers enqueue

- **WHEN** Live weld `lens_det` returns `ok=false` and `code=-3` with reason `insufficient_regions_after_erode`
- **AND** `input_frame.jpg` exists for that frame
- **THEN** the App SHALL append a pending task under `files/ai_upload/yyyy/mm/dd/lens/tasks/<uuid>/`
- **AND** SHALL schedule `AiUploadDrainWorker`

#### Scenario: Frame rejected does not trigger enqueue

- **WHEN** Live weld `lens_det` returns `code=-5` (`FRAME_REJECTED`, e.g. `overexposed`)
- **THEN** the App MUST NOT enqueue an ai-report task for that frame
- **AND** burst sampling behavior SHALL remain unchanged

#### Scenario: Lens contamination detection disabled skips enqueue

- **WHEN** `AiAssistanceSettings.isLensContaminationDetectionEnabled()` is false
- **AND** Live weld `lens_det` returns `code=-3`
- **THEN** the App MUST NOT enqueue an ai-report task

#### Scenario: Missing failure image skips enqueue

- **WHEN** Live weld `lens_det` returns `code=-3`
- **AND** no readable `input_frame.jpg` is available for that frame
- **THEN** the App MUST NOT call `AiUploadCoordinator.enqueue`
- **AND** SHALL log a warning with `frame_id` and `reason`

### Requirement: Native lens_det SHALL persist input_frame.jpg on DETECT_FAILED

When `analyzeOpencvStainDetectBgr` determines a `kDetectFailed` (`code == -3`) outcome for stream-detect Live samples, native code SHALL write the input BGR frame to `input_frame.jpg` under the per-frame output directory passed to the analyzer, and SHALL include that path in the summary `written_files` list (or equivalent field parsed by Java).

Native code SHALL NOT write `input_frame.jpg` for `kFrameRejected` (`code == -5`) outcomes in this iteration.

#### Scenario: Detect failed writes input frame

- **WHEN** stream detect invokes `lens_det` and the pipeline returns `code=-3`
- **THEN** native output SHALL include a readable `input_frame.jpg` path under the frame output directory

#### Scenario: Frame rejected does not write input frame for upload

- **WHEN** stream detect invokes `lens_det` and red-frame gate returns `code=-5`
- **THEN** native code MUST NOT write `input_frame.jpg` solely for ai-report upload purposes

### Requirement: Per-frame output directories SHALL prevent cross-frame file overwrite

For Live `StreamDetectPipeline` `lens_det` invocations, the system SHALL use a distinct output subdirectory per sampled `frame_id` (or per-sample timestamp) under the session base output directory, so `input_frame.jpg` and `target.json` from different samples do not overwrite each other.

#### Scenario: Two consecutive samples retain distinct failure images

- **WHEN** two Live weld samples both return `code=-3` in the same laser-on session
- **THEN** each sample SHALL have its own output subdirectory containing its own `input_frame.jpg`
