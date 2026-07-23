## MODIFIED Requirements

### Requirement: App SHALL expose a Lens Guard capability profile after engine start

After `AiManager` successfully loads native libraries and creates the OpenCV stain-detect session, the system SHALL build and expose **`AiEngineCapabilityProfile`**. On emulators that block RKNN session creation, **`isOpencvStainDetectSessionActive()`** MAY still be true when `libai.so` loads and the OpenCV session starts.

#### Scenario: Emulator OpenCV session without RKNN

- **WHEN** the App runs on an emulator with `AiNativeRuntime.blocksRknnSession()` true
- **AND** OpenCV stain detect session creation succeeds
- **THEN** `isOpencvStainDetectSessionActive()` MUST be true
- **AND** process-video Detect MUST be able to proceed without RKNN `isRknnEngineRunning()`
