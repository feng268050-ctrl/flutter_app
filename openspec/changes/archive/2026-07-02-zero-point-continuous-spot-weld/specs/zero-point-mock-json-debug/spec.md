## MODIFIED Requirements

### Requirement: Staging non-release uses mock when file present

When `BuildConfig.RELEASE_CHANNEL` is `false`, before calling native zero-point detect for a laser-on sample, the system SHALL attempt to read and parse the mock file. If parsing succeeds, the system SHALL use that sample and SHALL NOT call native detect for that sample.

Mock loading SHALL apply only to **`ZeroPointDetectCoordinator`** and **`ZeroPointManualAutoCoordinator`** (unified `nativeOpencvZeroPointDetectFromI420` path). Laser-on zero-point production SHALL NOT route mock through `EdgeDrawingDetectCoordinator`.

#### Scenario: Mock file present on staging build

- **WHEN** `RELEASE_CHANNEL` is false and `/sdcard/lws_debug/zero_point_mock.json` exists and is readable
- **THEN** `ZeroPointDetectCoordinator` and `ZeroPointManualAutoCoordinator` SHALL use the parsed sample for that detect invocation
- **AND** SHALL log a mock hit at info level with path and offset values

#### Scenario: Mock file absent

- **WHEN** `RELEASE_CHANNEL` is false and the mock file does not exist or is unreadable
- **THEN** sample generation SHALL fall back to native zero-point detect

#### Scenario: Invalid mock JSON

- **WHEN** the mock file exists but content is not valid JSON for `ZeroPointDetectJson.parse`
- **THEN** the system SHALL treat as mock miss and fall back to native detect

### Requirement: Mock participates in existing correction pipelines

Mock samples SHALL feed the same aggregation and correction logic as native samples in both `ZeroPointDetectCoordinator` (laser-on production task) and `ZeroPointManualAutoCoordinator` (Advanced Settings Auto), including tolerance checks, `ZeroPointCorrectionWriter`, and production zero-point offset alert pending when applicable.

Mock samples SHALL apply on L1 and L1 Pro alike through the unified zero-point coordinator path.

#### Scenario: Production path correction from mock

- **WHEN** a staging build runs a laser-on zero-point task with mock returning `offset_x=-9.0` on every sample
- **THEN** task finalization SHALL compute `uiDelta` from mean offset and MAY invoke `ZeroPointCorrectionWriter` per existing tolerance rules
- **AND** SHALL set production zero-point offset alert pending when scope and tolerance rules match existing production behavior

#### Scenario: L1 Pro production path uses zero-point mock coordinator

- **WHEN** a staging build on L1 Pro runs a laser-on detect round with mock returning valid out-of-tolerance offsets on every sample
- **THEN** `ZeroPointDetectCoordinator` finalize on laser OFF SHALL apply correction through the same writer path as native zero-point samples

#### Scenario: Manual Auto correction from mock

- **WHEN** a staging build runs Manual Auto with mock returning a valid out-of-tolerance sample
- **THEN** completion SHALL apply incremental correction through `ZeroPointCorrectionWriter` using the same mapping as native samples
