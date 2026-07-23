## MODIFIED Requirements

### Requirement: Capability profile is built after engine start

After `AiManager` successfully loads native libraries and creates the configured sessions, the system SHALL build and expose a read-only **`AiEngineCapabilityProfile`** (or equivalent) that aggregates engine capabilities relevant to UI and workflow branching.

#### Scenario: Profile reflects RKNN availability

- **WHEN** RKNN session starts on a capable device
- **THEN** `AiEngineCapabilityProfile.isRknnStainDetectAvailable()` MUST be true
- **AND** classification/detection flags MUST reflect native config

#### Scenario: Emulator libs-only without RKNN session

- **WHEN** the App runs on an emulator that blocks RKNN session creation but loads `libai.so`
- **THEN** `isRknnStainDetectAvailable()` MAY be false
- **AND** OpenCV stain detect MAY still be available via `isOpencvStainDetectSessionActive()`

### Requirement: UI branches on capability profile not hard-coded cls assumptions

Application code that branches on whether classification or laser MONITORING is expected SHALL consult **`AiEngineCapabilityProfile`** (or methods delegated from **`AiManager`**) rather than hard-coded assumptions.

#### Scenario: Focus monitoring expectation

- **WHEN** classification is enabled and RKNN session is running
- **THEN** `isFocusMonitoringExpected()` MUST be true

## REMOVED Requirements

### Requirement: LensGuard capability profile after nativeCreate

**Reason**: Renamed to `AiEngineCapabilityProfile`; `LensGuardManager` removed.

**Migration**: Use `AiManager.getCapabilityProfile()` (or equivalent accessor).
