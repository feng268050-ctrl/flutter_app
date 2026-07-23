## Context

Laser-on zero-point detection uses two native detect entry points:

| Algorithm | JNI | Role |
|-----------|-----|------|
| `ZERO_POINT` | `nativeOpencvZeroPointDetectFromI420` | L1 spot detect |
| `ScanVChannelRadialAdaptive` | `nativeOpencvEdgeDrawingDetectFromI420` | L1 Pro plasma circle detect |

Both native implementations are **detection-only**: one I420 frame + ROI in, one JSON out. They do not read Machine Model, choose backends, hold cross-frame aggregation state for App production paths, or write Modbus. Java calls native **once per accepted PR1 sample**; multi-sample smoothing is the Java cluster reducer on laser OFF.

`ScanVChannelRadialAdaptive` currently has native EMA temporal state (`g_scan_v_channel_radial_adaptive_temporal`) — this violates one-frame-one-result and SHALL be removed from the JNI production path.

Today Java runs **two coordinators** in parallel (`ZeroPointDetectCoordinator`, `EdgeDrawingDetectCoordinator`), gated only at finalize time by `BuildConfig.USE_EDGEDRAWING_ZERO_DETECT`. Product scope is **two models only**: **L1** and **L1 Pro**.

Machine Model comes from `DeviceModelConfig.getModel()` (ROM `/system/etc/model.properties`). Normalization via `ProcessLibraryAssetSelector.normalizeDeviceModel()` strips `LaserCyber` prefix.

## Goals / Non-Goals

**Goals:**

- **Java selects detect algorithm** by Machine Model and invokes the matching `NativeBridge` function per sample.
- **1:1 mapping**: L1 → `ZERO_POINT`; L1 Pro → `ScanVChannelRadialAdaptive`.
- One detect call per PR1 sample — never both JNI paths on the same frame.
- Keep existing laser-on round lifecycle, `LaserDetectSamplingCoordinator` gates, cluster reducer, tolerance, and Modbus correction in Java.
- **`ScanVChannelRadialAdaptive`**: stateless per JNI call (same contract as `ZERO_POINT`); Java 传一帧检测一帧.
- **Shared mock**: L1 Pro path uses `/sdcard/lws_debug/zero_point_mock.json` via existing `ZeroPointMockJsonLoader`.

**Non-Goals:**

- Machine Model or routing logic inside native detect code.
- Models beyond L1 / L1 Pro.
- Routing `LENS_DET` or other AI modules.
- Changing detect algorithms, ROI assets, or JSON contract.
- Runtime UI toggle of algorithm.

## Decisions

### 1. Separation: detect vs orchestration

**Choice:** Native = detect only. Java = model → JNI function selection + all post-detect behavior (aggregate, clamp, Modbus 0090H, overlay, burst mode).

**Rationale:** Matches product intent; keeps algorithms testable in isolation (host infer CLI) without ROM dependencies.

### 2. Java algorithm selector

**Choice:** Add `ZeroPointDetectAlgorithmSelector` (name TBD) in `com.lasercyber.lws.ai`:

```java
enum Algorithm { ZERO_POINT, SCAN_V_CHANNEL_RADIAL_ADAPTIVE }

Algorithm resolve(String rawModel)  // uses normalizeDeviceModel
void detect(long handle, ByteBuffer i420, int w, int h)  // dispatches to correct NativeBridge.*
```

`resolve()` is called once at attach (model does not change at runtime). Per-sample work calls the selected JNI only.

**Rationale:** Single dispatch site documents “Java picks function”; avoids duplicating model parsing.

### 3. Model matching (two models only)

**Choice:** After `normalizeDeviceModel(raw)`:

| Normalized (case-insensitive) | JNI |
|-------------------------------|-----|
| `L1 Pro` | `nativeOpencvEdgeDrawingDetectFromI420` |
| `L1` | `nativeOpencvZeroPointDetectFromI420` |

Evaluate **L1 Pro before L1** (equality, not substring). Product has no other models; if ROM normalizes to anything else, log warning and default to `ZERO_POINT` (defensive only).

### 4. Coordinator gating (minimal change)

**Choice:** Keep both coordinators attached but gate so **only the coordinator whose algorithm matches** runs rounds and calls its JNI:

- L1: `ZeroPointDetectCoordinator` active; `EdgeDrawingDetectCoordinator` idle.
- L1 Pro: reverse.

Inactive coordinator: no `activeEventId`, no native detect calls, no Modbus correction for laser-on rounds.

**Alternative considered:** Merge into one coordinator with internal `switch (algorithm)` — cleaner long-term but larger refactor; gating is sufficient for “Java function selection” now.

### 5. Remove `USE_EDGEDRAWING_ZERO_DETECT`

**Choice:** Delete production use of the Gradle flag. Active algorithm from selector owns pending-store clear and Modbus write (same logic as today’s flag branches).

### 6. Burst mode

**Choice:** No change to `LaserDetectSamplingCoordinator`. Inactive coordinator has no active round, so burst exit ignores it.

### 7. ScanVChannelRadialAdaptive: one frame, one JSON (no native temporal state)

**Choice:** Remove native EMA smoothing from `detectScanVChannelRadialAdaptiveInBox` for App JNI calls. Each invocation uses only the current frame; output JSON reflects that frame alone. Java multi-sample behavior unchanged (cluster reducer on laser OFF).

**Rationale:** Product requires parity with `ZERO_POINT` — detect function is a pure frame transform. Offline host-infer may keep optional smoothing via CLI flag later; not in App JNI path.

**Alternative considered:** Keep EMA in native — rejected; couples detect quality to call history and complicates mock/debug.

### 8. Shared `zero_point_mock.json` for both algorithms

**Choice:** `EdgeDrawingDetectCoordinator.runNativeSample` mirrors `ZeroPointDetectCoordinator`:

1. If `ZeroPointMockJsonLoader.tryLoadSample()` returns non-null → use sample (map to `EdgeDrawingDetectJson.Sample`; optional `base_x`/`base_y` in mock JSON for overlay).
2. Else → `nativeOpencvEdgeDrawingDetectFromI420`.

Same path, `RELEASE_CHANNEL` gate, and log tag pattern as zero-point mock spec.

**Rationale:** One staging file for both L1 and L1 Pro debug; no second mock path.

## Risks / Trade-offs

- **[Risk] ROM model typo** → defensive default `ZERO_POINT` + attach log with normalized model and selected algorithm.
- **[Risk] Dual JNI during migration** → gating ensures only one function per sample.
- **[Trade-off] Two coordinator classes** → some duplication until a future single-coordinator refactor; selection principle still holds at JNI call site.
- **[Trade-off] Removing native EMA** → single-frame radius may be noisier; Java cluster reducer compensates across laser-on samples.

## Migration Plan

1. Add selector + unit tests (L1, L1 Pro, prefixed strings).
2. Gate coordinators; wire Modbus path to active algorithm only.
3. Remove native EMA from `ScanVChannelRadialAdaptive` JNI path.
4. Wire `EdgeDrawingDetectCoordinator` to `ZeroPointMockJsonLoader`.
5. Remove `USE_EDGEDRAWING_ZERO_DETECT` from production paths.
6. Emulator verify: L1 → zero_point JNI only; L1 Pro → edgedrawing JNI; mock file skips native on both.
7. Rollback: revert Java + native EMA removal.

## Open Questions

- None for product scope (L1 / L1 Pro only). Confirm whether misconfigured ROM should hard-fail vs default to `ZERO_POINT`.
