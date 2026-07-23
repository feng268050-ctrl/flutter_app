## MODIFIED Requirements

### Requirement: Product supports two Machine Models mapped to two detect algorithms

The supported Machine Models SHALL remain **L1** and **L1 Pro** (after `ProcessLibraryAssetSelector.normalizeDeviceModel`).

For **laser-on zero-point production** (`ZeroPointDetectCoordinator`, `ZeroPointManualAutoCoordinator` when tied to laser-on sampling), Java SHALL always select algorithm **`ZERO_POINT`** and SHALL invoke **`nativeOpencvZeroPointDetectFromI420`** only. Weld-mode Point/Line selection SHALL follow `zero-point-line-detect`, not Machine Model.

`ScanVChannelRadialAdaptive` / `nativeOpencvEdgeDrawingDetectFromI420` MAY remain in the codebase for offline tools and future use but SHALL NOT be selected for laser-on zero-point production on any Machine Model.

| Context | Java JNI |
|---------|----------|
| Laser-on zero-point (all models) | `nativeOpencvZeroPointDetectFromI420` |
| Offline / non-production EdgeDrawing CLI | `nativeOpencvEdgeDrawingDetectFromI420` (unchanged, out of laser-on path) |

#### Scenario: L1 laser-on zero point uses ZERO_POINT

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1` and a laser-on zero-point sample runs
- **THEN** Java SHALL select algorithm `ZERO_POINT`
- **AND** per-sample detect SHALL invoke `nativeOpencvZeroPointDetectFromI420`

#### Scenario: L1 Pro laser-on zero point also uses ZERO_POINT

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1 Pro` and a laser-on zero-point sample runs
- **THEN** Java SHALL select algorithm `ZERO_POINT`
- **AND** per-sample detect SHALL invoke `nativeOpencvZeroPointDetectFromI420`
- **AND** SHALL NOT invoke `nativeOpencvEdgeDrawingDetectFromI420`

#### Scenario: Prefixed ROM model string

- **WHEN** ROM model is `LaserCyber L1 Pro`
- **THEN** normalization SHALL yield `L1 Pro`
- **AND** laser-on zero-point detect SHALL still use `nativeOpencvZeroPointDetectFromI420`

### Requirement: Java SHALL select detect algorithm; native SHALL only detect

Detect algorithms (`ZERO_POINT`, `ScanVChannelRadialAdaptive`) SHALL perform frame detection only and return JSON. They SHALL NOT read Machine Model, SHALL NOT choose between algorithms, and SHALL NOT perform Modbus writes or cluster aggregation.

For laser-on zero-point production, Java orchestration SHALL choose **`ZERO_POINT`** unconditionally and SHALL pass **detect target mode** (Point or Line) into the zero-point native session based on active weld model type.

Native `zero_point` SHALL NOT branch on `DeviceModelConfig` or ROM model strings.

#### Scenario: Native has no model routing

- **WHEN** native zero_point detect runs
- **THEN** native code SHALL NOT branch on `DeviceModelConfig` or ROM model strings

#### Scenario: Java dispatches one JNI per laser-on zero-point sample

- **WHEN** a PR1 laser-on zero-point sample is accepted for detect
- **THEN** Java SHALL call `nativeOpencvZeroPointDetectFromI420` exactly once
- **AND** SHALL NOT call `nativeOpencvEdgeDrawingDetectFromI420` on that sample

### Requirement: Inactive algorithm SHALL NOT run on PR1 frames

For laser-on zero-point production rounds, Java SHALL NOT invoke `nativeOpencvEdgeDrawingDetectFromI420`. Java SHALL invoke `nativeOpencvZeroPointDetectFromI420` for all Machine Models.

#### Scenario: L1 Pro skips ScanVChannelRadialAdaptive JNI on laser-on zero point

- **WHEN** resolved Machine Model is `L1 Pro` and laser-on zero-point sampling is active
- **THEN** `nativeOpencvEdgeDrawingDetectFromI420` SHALL NOT be called

#### Scenario: L1 skips EdgeDrawing JNI on laser-on zero point

- **WHEN** resolved Machine Model is `L1` and laser-on zero-point sampling is active
- **THEN** `nativeOpencvEdgeDrawingDetectFromI420` SHALL NOT be called

### Requirement: Algorithm resolution SHALL be logged at attach

When laser-on zero-point coordinators attach, Java SHALL log normalized Machine Model and that laser-on zero-point algorithm is **`ZERO_POINT`** with weld-mode routing enabled.

#### Scenario: Attach log

- **WHEN** zero-point coordinators attach at startup
- **THEN** logs SHALL include normalized model and `ZERO_POINT` for laser-on zero-point path

## REMOVED Requirements

### Requirement: ScanVChannelRadialAdaptive SHALL be stateless per JNI call

**Reason**: Laser-on zero-point production no longer invokes EdgeDrawing JNI; stateless EdgeDrawing behavior remains documented in native/offline specs only.

**Migration**: Retain requirement in native EdgeDrawing module docs if needed; laser-on App path uses zero_point only.
