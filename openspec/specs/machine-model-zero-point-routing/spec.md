# machine-model-zero-point-routing Specification

## Purpose
Laser-on zero-point production always uses native `zero_point` via `StreamDetectPipeline`; EdgeDrawing (`ScanVChannelRadialAdaptive`) remains CLI/offline-only.
## Requirements
### Requirement: Product supports two Machine Models with unified laser-on zero-point algorithm

The supported Machine Models SHALL remain **L1** and **L1 Pro** (after `ProcessLibraryAssetSelector.normalizeDeviceModel`).

For **laser-on zero-point production** (`ZeroPointDetectCoordinator`, `ZeroPointManualAutoCoordinator` when tied to laser-on sampling), Java SHALL always use native module **`zero_point`** through **`StreamDetectPipeline`** / **`StreamDetectResultBus`**. Weld-mode Point/Line selection SHALL follow `zero-point-line-detect`, not Machine Model.

`ScanVChannelRadialAdaptive` / EdgeDrawing JNI (`nativeOpencvEdgeDrawingDetectFromNv12` and related) MAY remain in the codebase for **offline CLI tools** (`edgedrawing_infer`) but SHALL NOT be selected for laser-on zero-point production on any Machine Model. The App SHALL NOT publish EdgeDrawing overlay state on AI Vision.

| Context | Detect path |
|---------|-------------|
| Laser-on zero-point (all models) | `StreamDetectPipeline` module `zero_point` → `StreamDetectResultBus` |
| Offline EdgeDrawing CLI | `nativeOpencvEdgeDrawingDetectFromNv12` / `FromJpg` (out of laser-on App path) |

#### Scenario: L1 laser-on zero point uses ZERO_POINT via stream detect

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1` and a laser-on zero-point sample runs
- **THEN** Java SHALL consume `detect_result` events with `module=zero_point`
- **AND** SHALL NOT invoke per-sample Java `nativeOpencvZeroPointDetectFromI420` on live PR1 frames

#### Scenario: L1 Pro laser-on zero point also uses ZERO_POINT via stream detect

- **WHEN** `DeviceModelConfig.getModel()` normalizes to `L1 Pro` and a laser-on zero-point sample runs
- **THEN** Java SHALL consume `detect_result` events with `module=zero_point`
- **AND** SHALL NOT invoke `nativeOpencvEdgeDrawingDetectFromNv12` on that sample

#### Scenario: Prefixed ROM model string

- **WHEN** ROM model is `LaserCyber L1 Pro`
- **THEN** normalization SHALL yield `L1 Pro`
- **AND** laser-on zero-point detect SHALL still use `StreamDetectPipeline` module `zero_point`

### Requirement: Java SHALL select detect algorithm; native SHALL only detect

Detect algorithms (`ZERO_POINT`, `ScanVChannelRadialAdaptive`) SHALL perform frame detection only and return JSON. They SHALL NOT read Machine Model, SHALL NOT choose between algorithms, and SHALL NOT perform Modbus writes or cluster aggregation.

For laser-on zero-point production, Java orchestration SHALL choose **`zero_point`** unconditionally and SHALL pass **detect target mode** (Point or Line) into the native session based on active weld model type.

Native `zero_point` SHALL NOT branch on `DeviceModelConfig` or ROM model strings.

#### Scenario: Native has no model routing

- **WHEN** native zero_point detect runs
- **THEN** native code SHALL NOT branch on `DeviceModelConfig` or ROM model strings

#### Scenario: Java does not dispatch EdgeDrawing on laser-on zero-point samples

- **WHEN** a PR1 laser-on zero-point sample is accepted for detect
- **THEN** Java SHALL NOT call `nativeOpencvEdgeDrawingDetectFromNv12` on that sample
- **AND** `StreamDetectPipeline` SHALL NOT enable `edgedrawing_enabled` for production weld sessions

### Requirement: Inactive algorithm SHALL NOT run on PR1 frames

For laser-on zero-point production rounds, Java and `StreamDetectPipeline` SHALL NOT invoke EdgeDrawing detect on PR1 frames. Only `zero_point` SHALL run for laser-on zero-point production.

#### Scenario: L1 Pro skips ScanVChannelRadialAdaptive on laser-on zero point

- **WHEN** resolved Machine Model is `L1 Pro` and laser-on zero-point sampling is active
- **THEN** `nativeOpencvEdgeDrawingDetectFromNv12` SHALL NOT be called
- **AND** EdgeDrawing overlay state SHALL NOT be published in the App

#### Scenario: L1 skips EdgeDrawing on laser-on zero point

- **WHEN** resolved Machine Model is `L1` and laser-on zero-point sampling is active
- **THEN** `nativeOpencvEdgeDrawingDetectFromNv12` SHALL NOT be called

### Requirement: Algorithm resolution SHALL be logged at attach

When laser-on zero-point coordinators attach, Java SHALL log that laser-on zero-point algorithm is **`ZERO_POINT`** with weld-mode routing enabled.

#### Scenario: Attach log

- **WHEN** zero-point coordinators attach at startup
- **THEN** logs SHALL include `ZERO_POINT` for the laser-on zero-point path
