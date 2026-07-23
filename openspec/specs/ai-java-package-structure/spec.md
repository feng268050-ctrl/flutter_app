# ai-java-package-structure Specification

## Purpose
TBD - created by archiving change ai-library-optimization. Update Purpose after archive.
## Requirements
### Requirement: Java ai package SHALL be organized by domain subpackages

The App SHALL reorganize `com.lasercyber.lws.ai` from a flat package into domain subpackages at minimum: `bridge`, `engine`, `stream`, `stain`, `zeropoint`, `sampling`, and `model`. Migration MUST proceed one subpackage per PR with full compile verification after each batch.

#### Scenario: Subpackage migration preserves public API

- **WHEN** a subpackage migration PR merges
- **THEN** existing public entry points such as `AiManager.getInstance()` MUST remain callable without signature changes
- **AND** internal implementation MAY delegate to relocated classes

#### Scenario: No single file exceeds line limit after migration

- **WHEN** Phase 3 Java restructuring is complete
- **THEN** no file under `com.lasercyber.lws.ai` SHALL exceed 1500 lines
- **AND** non-bridge files SHOULD target ≤500 lines (bridge layer ≤800)

### Requirement: Legacy Java frame-push APIs SHALL be removed or deprecated

The App SHALL remove or annotate `@Deprecated` Java APIs with no external callers that imply live Java-driven frame push is the primary path, including at minimum `AiManager.onBitmapFrame`, `tryAcceptOpencv*`, and `tryAcceptRknn*`. Documentation MUST state that live inference is driven by C++ `StreamDetectPipeline`.

#### Scenario: Deprecated APIs have no live callers

- **WHEN** Phase 1 legacy cleanup completes
- **THEN** static analysis or CI grep MUST confirm no production call sites for removed APIs
- **AND** `RKNN_STAIN_INFER_ACTIVE` MUST remain documented as reserved for future use, not active live path

#### Scenario: Offline one-shot APIs remain available

- **WHEN** process-video or offline manual stages invoke OpenCV detect
- **THEN** `opencvStainDetectFromNv12` / `opencvStainDetectFromJpg` one-shot APIs MUST remain available
- **AND** MUST NOT be removed as part of legacy cleanup

### Requirement: AI core packages SHALL NOT depend on UI View classes

Packages under `com.lasercyber.lws.ai` (excluding documented bridge adapters) MUST NOT import `ui.*.view`, `Fragment`, or `DetectionOverlayView`. Result DTOs in `model` MUST use pure geometry types (e.g. `NormalizedBox` with x, y, w, h in 0..1).

#### Scenario: Stain result uses normalized geometry

- **WHEN** `AiStainDetectResult` is constructed from native JSON
- **THEN** bounding boxes MUST be stored as `List<NormalizedBox>` or equivalent
- **AND** MUST NOT reference `DetectionOverlayView.OverlayBox`

#### Scenario: Consecutive OK filter decoupled from timeline class

- **WHEN** `LensDetConsecutiveOkFilter` evaluates sample timing
- **THEN** it MUST accept `int sampleIndexMs` (or equivalent primitive) as input
- **AND** MUST NOT import `ProcessVideoAiTimeline`

### Requirement: ZeroPointManualAutoCoordinator SHALL be split into focused classes

`ZeroPointManualAutoCoordinator` MUST be decomposed into at minimum: `ZeroPointManualAutoWorkflow` (state machine), `ZeroPointLaserController` (Modbus / laser), and `ZeroPointVideoAnalyzer` (offline video sampling). The split MAY land as a separate PR within Phase 3.

#### Scenario: Manual auto workflow regression

- **WHEN** the split classes replace the monolithic coordinator
- **THEN** the full manual zero-point auto-correction flow MUST pass instrument testing
- **AND** public coordinator facade MUST remain for callers until explicitly migrated

