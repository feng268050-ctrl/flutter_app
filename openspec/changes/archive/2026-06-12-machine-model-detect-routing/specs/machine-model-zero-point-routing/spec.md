## ADDED Requirements

### Requirement: Product supports two Machine Models mapped to two detect algorithms

The supported Machine Models SHALL be exactly **L1** and **L1 Pro** (after `ProcessLibraryAssetSelector.normalizeDeviceModel`: strip optional `LaserCyber` prefix, collapse whitespace). The supported laser-on detect algorithms SHALL be exactly:

| Normalized model | Algorithm | Java JNI |
|------------------|-----------|----------|
| `L1` | `ZERO_POINT` | `NativeBridge.nativeOpencvZeroPointDetectFromI420` |
| `L1 Pro` | `ScanVChannelRadialAdaptive` | `NativeBridge.nativeOpencvEdgeDrawingDetectFromI420` |

`L1 Pro` matching SHALL be evaluated before `L1` matching so `L1 Pro` is never classified as `L1`.

#### Scenario: L1 selects ZERO_POINT

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1`
- **THEN** Java SHALL select algorithm `ZERO_POINT`
- **AND** per-sample detect SHALL invoke `nativeOpencvZeroPointDetectFromI420`

#### Scenario: L1 Pro selects ScanVChannelRadialAdaptive

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1 Pro`
- **THEN** Java SHALL select algorithm `ScanVChannelRadialAdaptive`
- **AND** per-sample detect SHALL invoke `nativeOpencvEdgeDrawingDetectFromI420`

#### Scenario: Prefixed ROM model string

- **WHEN** ROM model is `LaserCyber L1 Pro`
- **THEN** normalization SHALL yield `L1 Pro`
- **AND** Java SHALL select `ScanVChannelRadialAdaptive`

### Requirement: Java SHALL select detect algorithm; native SHALL only detect

Detect algorithms (`ZERO_POINT`, `ScanVChannelRadialAdaptive`) SHALL perform frame detection only and return JSON. They SHALL NOT read Machine Model, SHALL NOT choose between algorithms, and SHALL NOT perform Modbus writes or cluster aggregation.

Java orchestration (laser-on rounds, sampling gates, cluster reducer, correction mapping, Modbus 0090H, overlay) SHALL remain in Java coordinators. Java SHALL choose which native detect function to call based on resolved Machine Model.

#### Scenario: Native has no model routing

- **WHEN** native zero-point or EdgeDrawing detect runs
- **THEN** native code SHALL NOT branch on `DeviceModelConfig` or ROM model strings

#### Scenario: Java dispatches one JNI per sample

- **WHEN** a PR1 laser-on sample is accepted for detect
- **THEN** Java SHALL call exactly one of `nativeOpencvZeroPointDetectFromI420` or `nativeOpencvEdgeDrawingDetectFromI420` according to the resolved algorithm
- **AND** SHALL NOT call both on the same sample

### Requirement: ScanVChannelRadialAdaptive SHALL be stateless per JNI call

`ScanVChannelRadialAdaptive` SHALL treat each native detect invocation independently: one input I420 frame SHALL produce one output JSON with no dependency on prior frames in native state. Java SHALL invoke native detect once per accepted PR1 sample (Java 传一帧检测一帧). Multi-sample temporal behavior SHALL remain in Java (cluster reducer on laser OFF), not in native detect.

Native `ScanVChannelRadialAdaptive` SHALL NOT maintain cross-call temporal smoothing (e.g. EMA) on the App JNI production path.

#### Scenario: Consecutive JNI calls do not share native smooth state

- **WHEN** Java calls `nativeOpencvEdgeDrawingDetectFromI420` twice with different frames in the same laser-on round
- **THEN** the second result SHALL depend only on the second frame
- **AND** native SHALL NOT blend the second result with the first via internal temporal state

#### Scenario: One PR1 sample maps to one detect call

- **WHEN** `LaserDetectSamplingCoordinator` accepts one PR1 sample for L1 Pro detect
- **THEN** Java SHALL perform at most one native detect invocation (or one mock read) for that sample

### Requirement: Inactive algorithm SHALL NOT run on PR1 frames

When algorithm is `ZERO_POINT`, Java SHALL NOT invoke `nativeOpencvEdgeDrawingDetectFromI420` for laser-on rounds. When algorithm is `ScanVChannelRadialAdaptive`, Java SHALL NOT invoke `nativeOpencvZeroPointDetectFromI420` for laser-on rounds.

#### Scenario: L1 skips ScanVChannelRadialAdaptive JNI

- **WHEN** resolved algorithm is `ZERO_POINT` and laser is ON
- **THEN** `nativeOpencvEdgeDrawingDetectFromI420` SHALL NOT be called

#### Scenario: L1 Pro skips ZERO_POINT JNI

- **WHEN** resolved algorithm is `ScanVChannelRadialAdaptive` and laser is ON
- **THEN** `nativeOpencvZeroPointDetectFromI420` SHALL NOT be called

### Requirement: Algorithm resolution SHALL be logged at attach

When laser-on detect coordinators attach, Java SHALL log normalized Machine Model and selected algorithm once.

#### Scenario: Attach log

- **WHEN** coordinators attach at startup
- **THEN** logs SHALL include normalized model and algorithm (`ZERO_POINT` or `ScanVChannelRadialAdaptive`)
