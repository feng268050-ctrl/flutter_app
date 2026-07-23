## MODIFIED Requirements

### Requirement: Staging non-release uses mock when file present

When `BuildConfig.RELEASE_CHANNEL` is `false`, before calling native zero-point detect for a laser-on sample, the system SHALL attempt to read and parse the mock file. If parsing succeeds, the system SHALL use that sample and SHALL NOT call native detect for that sample.

Mock loading SHALL apply only to **`ZeroPointDetectCoordinator`** and **`ZeroPointManualAutoCoordinator`** (unified zero-point detect path). When mock is not used and Java submits an offline retriever frame, native detect SHALL use **`nativeOpencvZeroPointDetectFromNv12`**. Laser-on live zero-point production SHALL NOT route mock through `EdgeDrawingDetectCoordinator`.

#### Scenario: Mock file present on staging build

- **WHEN** `RELEASE_CHANNEL` is false and `/sdcard/lws_debug/zero_point_mock.json` exists and is readable
- **THEN** `ZeroPointDetectCoordinator` and `ZeroPointManualAutoCoordinator` SHALL use the parsed sample for that detect invocation
- **AND** SHALL log a mock hit at info level with path and offset values

#### Scenario: Mock file absent

- **WHEN** `RELEASE_CHANNEL` is false and the mock file does not exist or is unreadable
- **THEN** sample generation SHALL fall back to native zero-point detect
