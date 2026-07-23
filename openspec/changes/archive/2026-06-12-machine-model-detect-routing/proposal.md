## Why

Laser-on zero-point detection currently relies on a compile-time `USE_EDGEDRAWING_ZERO_DETECT` flag while both `ZeroPointDetectCoordinator` and `EdgeDrawingDetectCoordinator` run in parallel on every PR1 frame. Only one path writes Modbus correction, but both still consume inference budget. The product line has **only two Machine Models** — **L1** and **L1 Pro** — and needs a **1:1 mapping** to two detect algorithms: `ZERO_POINT` (L1) and `ScanVChannelRadialAdaptive` (L1 Pro). Detect algorithms SHALL remain **detection-only**; **Java** chooses which native detect function to call based on Machine Model from ROM `model.properties`.

## What Changes

- Introduce a Java-side algorithm selector from `DeviceModelConfig.getModel()` (normalized):
  - **L1** → call `NativeBridge.nativeOpencvZeroPointDetectFromI420` (`ZERO_POINT`)
  - **L1 Pro** → call `NativeBridge.nativeOpencvEdgeDrawingDetectFromI420` (`ScanVChannelRadialAdaptive`)
- Java orchestration (laser-on round, sampling gates, cluster reducer, Modbus correction, overlay) stays in coordinators; **only the per-sample native detect invocation** branches on model.
- Ensure exactly one detect function runs per PR1 sample — never both in parallel.
- Remove `BuildConfig.USE_EDGEDRAWING_ZERO_DETECT` as the production switch.
- Reuse `ProcessLibraryAssetSelector.normalizeDeviceModel` (`LaserCyber L1 Pro` → `L1 Pro`, `LaserCyber L1` → `L1`).
- **Native**: no Machine Model routing; both algorithms accept one I420 frame + ROI and return detect JSON only — **no cross-frame state** in `ScanVChannelRadialAdaptive` (Java passes one frame per JNI call; temporal aggregation stays in Java cluster reducer).
- **Mock debug**: `ScanVChannelRadialAdaptive` path SHALL reuse the same `/sdcard/lws_debug/zero_point_mock.json` staging mock as `ZERO_POINT` via `ZeroPointMockJsonLoader` (skip native when mock file present on non-release builds).

## Capabilities

### New Capabilities

- `machine-model-zero-point-routing`: Java-side mapping from the two supported Machine Models to the detect JNI entry (`ZERO_POINT` vs `ScanVChannelRadialAdaptive`).

### Modified Capabilities

- `zero-point-detect-on-laser-on`: Per-sample native invocation SHALL follow Java algorithm selection — `nativeOpencvZeroPointDetectFromI420` on L1, `nativeOpencvEdgeDrawingDetectFromI420` on L1 Pro — while round lifecycle, gates, reducer, and correction semantics stay unchanged.
- `zero-point-mock-json-debug`: Mock file SHALL apply to `EdgeDrawingDetectCoordinator` (L1 Pro / `ScanVChannelRadialAdaptive`) as well as existing zero-point coordinators.

## Impact

- **Java**: algorithm selector helper; coordinator gating; shared mock in `EdgeDrawingDetectCoordinator`; remove `USE_EDGEDRAWING_ZERO_DETECT` production use.
- **Native**: remove `ScanVChannelRadialAdaptive` JNI-path temporal EMA so each call is stateless (one frame in, one JSON out); detect-only, no model awareness.
- **Tests**: L1 / L1 Pro / prefixed model strings; verify inactive JNI is never called.
- **Out of scope**: other models, other detect modules (`LENS_DET`), native-side routing.
