## MODIFIED Requirements

### Requirement: Each sample uses I420 frame and zero-point native JNI

At each PR1-driven sample opportunity while laser is ON, the App SHALL obtain a snapshot I420 frame from the production sub-stream (PR1) latest-frame holder and run detect on a background executor without blocking Modbus or UI threads.

**Java** SHALL select the detect function from Machine Model (per `machine-model-zero-point-routing`):

- **L1** → `NativeBridge.nativeOpencvZeroPointDetectFromI420`
- **L1 Pro** → `NativeBridge.nativeOpencvEdgeDrawingDetectFromI420` (`ScanVChannelRadialAdaptive`)

Only the selected function SHALL be invoked per sample. Round lifecycle, sampling gates, JSON parsing, and correction semantics SHALL be unchanged regardless of which detect function runs.

#### Scenario: L1 calls zero-point JNI

- **WHEN** a PR1-driven sample is accepted, model is L1, and a fresh I420 snapshot is available
- **THEN** the App SHALL call `nativeOpencvZeroPointDetectFromI420` with that frame
- **AND** SHALL parse the returned JSON on the worker thread

#### Scenario: L1 Pro calls ScanVChannelRadialAdaptive JNI

- **WHEN** a PR1-driven sample is accepted, model is L1 Pro, and a fresh I420 snapshot is available
- **THEN** the App SHALL call `nativeOpencvEdgeDrawingDetectFromI420` with that frame
- **AND** SHALL NOT call `nativeOpencvZeroPointDetectFromI420` for that sample

#### Scenario: No frame available

- **WHEN** a sample opportunity occurs but no I420 snapshot is available
- **THEN** that sample SHALL be skipped
- **AND** the round SHALL continue on subsequent PR1 frames while laser remains ON
