## Context

- Native **zero-point** detect is implemented in `zero_point_core` and exposed via `NativeBridge` (`nativeCreateOpencvZeroPointDetector`, `nativeOpencvZeroPointDetectFromI420`, …). App business logic is **not wired**.
- **零点校正** (`zeroPointCorrection`, Modbus **0090H**, UI ±30) exists in Advanced Settings; **1 UI unit = 3px**; **+** moves zero **right**, **−** moves zero **left**.
- Native `offset_x` = `detected_x − reference_x` (pixels). To correct: **`uiDelta = round(-offset_x / 3)`** (JSON negative → UI increases).
- Live AI already uses **`AiFrameSamplingGate`** + **500ms** constants (`AI_VISION_LIVE`, `AI_VISION_PROCESS_VIDEO`). Production stain infer uses **PR1** I420 at **2000ms** via `ProductionInferenceStreamClient`.
- Laser ON/OFF is available on **`DeviceStatus.isLaserOn()`** via `MemoryCacheManager` / Modbus polling.

## Goals / Non-Goals

**Goals:**

- On **laser rising edge** (OFF→ON), run a **bounded zero-point detect task**:
  - First sample at **`T₀ + 500ms`**
  - Then every **500ms** until **`T₀ + 2000ms`** inclusive → **4 samples** at +500, +1000, +1500, +2000 ms
- Each sample: obtain **I420** frame (same family as production/AI Vision paths), call zero-point JNI, parse **`offset_x`**
- Aggregate valid samples → compute **`uiDelta`**, **add** to current `zeroPointCorrection`, **clamp [-30, 30]**, persist + Modbus write via existing Advanced Settings pipeline
- Use a **dedicated 500ms gate instance** (same interval as `AI_VISION_LIVE`, separate from production 2000ms gate and AI Vision preview gate)

**Non-Goals:**

- Replacing manual Advanced Settings zero offset UI
- Vertical correction from `offset_y` (unless product adds a register later)
- Running zero-point detect while laser stays OFF
- Changing RKNN stain infer intervals (still 2000ms on PR1)

## Decisions

### 1. Task scheduler: fixed deadlines vs decode-driven gate

**Decision:** **Handler/ScheduledExecutor** fires at `T₀+500`, `+1000`, `+1500`, `+2000`. Each tick pulls **latest I420 snapshot** from PR1 sub-stream (shared with production infer client).

**Rationale:** Product wording is time-based (“下一个 500ms … 持续 2 秒”), not “every decoded frame gated at 500ms”. Matches `ProcessVideoAiSession` timeline grid (500ms) more than decode callback rate.

**Alternative:** Gate every I420 callback at 500ms for 2s after laser ON — simpler but first sample timing depends on decode FPS.

### 2. Frame source: PR1 sub-stream latest-I420 buffer

**Decision:** Extend **`ProductionInferenceStreamClient`** (or a thin **`LatestI420FrameHolder`**) to retain the most recent I420 direct buffer + dimensions on each decode callback. Zero-point task reads snapshot on scheduled ticks.

**Rationale:** Laser-on production path already starts PR1; avoids second RTSP client. Recording (PR0) does not push AI frames.

**Alternative:** TextureView bitmap — wrong for weld/quick modes without AI Vision page.

### 3. Native JSON contract

**Decision:** Extend `frameResultToJson` to include **`"ok": true|false`** and **`"code": int`** alongside `offset_x` / `offset_y` so App can ignore failed samples (today failure also emits `0,0`).

**Rationale:** Avoid treating failed detect as “zero error”.

### 4. Aggregation and apply policy

**Decision:**

- Collect **`offset_x`** from samples with **`ok == true`**
- If **≥1** valid sample: **`meanOffsetX = average(valid offset_x)`**
- **`uiDelta = round(-meanOffsetX / 3.0)`**
- **`newUi = clamp(currentUi + uiDelta, -30, 30)`** (incremental correction per laser-on event)
- If **0** valid samples: **no write**; log warning

**Alternative:** Use last valid sample only — noisier; median — overkill for 4 samples.

### 5. Laser edge re-trigger

**Decision:** New laser ON while a task runs **cancels** pending scheduled samples and **starts a fresh** 4-sample task from new `T₀`.

### 6. Modbus / persistence

**Decision:** Reuse **`AdvancedSettingViewModel` / DAO update** + **`ModbusFiledBuilder.doCreateWriteDeviceSetting`** (or existing partial write helper if only 0090H changed) — same path as user editing SeekBar.

### 7. Coordinator placement

**Decision:** New **`ZeroPointDetectCoordinator`** (singleton, app-scoped):

- Registers **`MemoryCacheManager.OnCacheChangedListener`** for `DEVICE_STATUS_KEY`
- Detects **`!prevLaserOn && currentLaserOn`**
- Owns detector handle lifecycle (`nativeCreate…` / `nativeDestroy…`) and ROI JSON path (e.g. under `files/lens_guard/zero_point_roi.json` — deploy/bootstrap TBD)
- Does **not** block Modbus or UI thread; infer on **`zero-point-infer`** single-thread executor

### 8. Sampling constant

**Decision:** Add **`AiFrameSamplingInterval.ZERO_POINT_ON_LASER(500L)`** (same ms as AI Vision live, distinct enum for documentation/tests) even though scheduling is deadline-based.

## Risks / Trade-offs

- **[Risk] PR1 not streaming when laser ON** → no I420 at tick → skip sample; if all skip, no correction. **Mitigation:** ensure `ProductionInferenceStreamCoordinator` starts PR1 on laser ON before zero task (existing behavior); log missing frame.
- **[Risk] Concurrent native calls** (stain infer + zero-point) → **Mitigation:** separate JNI entry points; zero-point on dedicated executor; optional defer tick if `AiStainDetectCoordinator` busy (drop sample, not gate reset).
- **[Risk] `0,0` JSON without `ok`** → **Mitigation:** native JSON extension (Decision 3).
- **[Risk] Large correction jumps** → **Mitigation:** clamp ±30; optional max `|uiDelta|` per event in tasks if product wants (open).

## Migration Plan

1. Ship native JSON `ok`/`code` in same release as App coordinator (or gate App on min libai version).
2. Place ROI JSON on device during bootstrap / OTA assets.
3. Feature can ship enabled by default; rollback = disable coordinator listener via flag if needed (optional `BuildConfig` — only if requested in tasks).

## Open Questions

- Exact **ROI JSON** path and who publishes it to devices (bundled asset vs remote).
- Whether product wants **Toast** on auto-adjust vs silent log only.
- Whether **`uiDelta` is incremental** (design default) or **absolute** `round(-offset/3)` — proposal assumes **incremental per laser-on event**.
