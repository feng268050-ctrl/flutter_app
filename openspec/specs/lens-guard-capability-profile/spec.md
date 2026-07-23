# lens-guard-capability-profile Specification

## Purpose
TBD - created by archiving change lens-guard-engine-alignment-2026-05-19. Update Purpose after archive.
## Requirements
### Requirement: App SHALL expose a Lens Guard capability profile after engine start

After `AiManager` successfully loads native libraries and creates the OpenCV stain-detect session, the system SHALL build and expose **`AiEngineCapabilityProfile`**. On emulators that block RKNN session creation, **`isOpencvStainDetectSessionActive()`** MAY still be true when `libai.so` loads and the OpenCV session starts.

#### Scenario: Emulator OpenCV session without RKNN

- **WHEN** the App runs on an emulator with `AiNativeRuntime.blocksRknnSession()` true
- **AND** OpenCV stain detect session creation succeeds
- **THEN** `isOpencvStainDetectSessionActive()` MUST be true
- **AND** process-video Detect MUST be able to proceed without RKNN `isRknnEngineRunning()`

### Requirement: Capability profile SHALL be the preferred gate for cls and MONITORING expectations

Application code that branches on whether classification or laser MONITORING is expected SHALL consult **`AiEngineCapabilityProfile`** (or methods delegated from **`AiManager`**) rather than hard-coded assumptions that cls is always enabled.

#### Scenario: UI checks before showing MONITORING label

- **WHEN** laser turns ON and `focusMonitoringExpected` is `false`
- **THEN** AI Vision overlay state text SHALL NOT wait indefinitely for `onStateChanged(1)`
- **AND** SHALL NOT treat absence of MONITORING as a streaming failure

### Requirement: Profile construction failures SHALL degrade safely

If `config.yaml` cannot be read or parsed, the system SHALL log a warning and apply engine-aligned defaults (`classificationEnabled=false`, `detectionEnabled=true`) rather than crashing startup.

#### Scenario: Missing config file

- **WHEN** the lens guard config path does not exist at profile build time
- **THEN** the profile SHALL use the defaults above
- **AND** Lens Guard engine startup SHALL continue if native create otherwise succeeds

#### Scenario: Android emulator (libs-only, no native session)

- **WHEN** the app runs on an emulator classified by `AiNativeRuntime.blocksRknnSession()`
- **THEN** `NativeBridge.ensureLoaded` MAY succeed (JNI symbols verified)
- **AND** `nativeCreate` and `nativeStart` SHALL NOT be invoked
- **AND** OpenCV stain detect MAY still be available via `AiManager.isOpencvStainDetectSessionActive()`
- **AND** `offlineInferJsonAvailable` and typed infer capability flags SHALL be `false` until a real device session is started
- **AND** inference entry points SHALL return structured errors without native SIGBUS

