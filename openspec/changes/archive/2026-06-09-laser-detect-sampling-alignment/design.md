## Context

- **zero_point** (`ZeroPointDetectCoordinator`): on laser OFF→ON, schedules 4 samples at `T₀+500/1000/1500/2000ms` via `mainHandler.postDelayed`; finalizes after the fourth attempt.
- **lens_det** (`OpencvStainDetectCoordinator`): continuous PR1 sampling while laser ON at **2000ms** (`LIVE_WELD`).
- **PR1 source**: `LivePr1InferenceStreamClient` → holder + lens_det; stream when laser ON and OpenCV session active.
- **Unified codes**: `code=-5` = `FRAME_REJECTED` with module-specific `reason`.

## Goals / Non-Goals

**Goals:**

- First zero_point sample on **first eligible PR1 frame** after laser rising edge.
- **Continuous** zero_point sampling while laser ON at **500ms** (no four-sample cap).
- **Finalize** zero_point correction (cluster reducer + Modbus) on **laser OFF**, not after a fixed sample count.
- **lens_det `LIVE_WELD` = 500ms** in normal mode (was 2000ms).
- **100ms burst** on `code=-5` until both modules have `code=0`; then restore **500ms** normal gates.
- Observable mode transitions in logcat.

**Non-Goals:**

- Native detection threshold / ROI changes.
- Burst on AI Vision live or process-video paths.
- Manual Auto flow beyond shared burst gates if it shares PR1.

## Decisions

### 1. PR1-driven continuous zero_point

| Phase | Behavior |
|-------|----------|
| Laser rising edge | Start task `eventId`; reset zero_point gate; accumulate valid samples in task buffer |
| Each PR1 frame | While laser ON, gate accepts (500ms normal / 100ms burst) → native detect → append valid offsets |
| Laser OFF | Cancel in-flight native work; run cluster reducer on all valid samples for that `eventId`; apply correction or skip write |
| Re-trigger laser ON | New `eventId`; fresh sample buffer (previous partial round discarded if laser cycled) |

No `postDelayed` schedule; no `sampleCount == 4` finalize.

### 2. lens_det LIVE_WELD = 500ms

**Decision:** Change `AiFrameSamplingInterval.LIVE_WELD` from `2000L` to `500L`. Normal mode aligns with `ZERO_POINT_ON_LASER` interval on the shared PR1 path.

**Alternatives:** Keep separate constants at same value — rejected; one constant documents live weld rate.

### 3. Shared burst coordinator

```text
NORMAL:
  lens_det gate = LIVE_WELD (500ms)
  zero_point gate = ZERO_POINT_ON_LASER (500ms)

BURST (FRAME_REJECTED):
  both gates = FRAME_REJECTED_BURST (100ms)
```

Enter on `code=-5` from either module; exit when both have `code=0` since burst start; laser OFF forces normal + zero_point finalize.

### 4. zero_point finalize on laser OFF

**Decision:** Move aggregate / `ZeroPointDetectClusterReducer` / `ZeroPointCorrectionWriter` from "after sample index 3" to `applyLaserState(laserOff)` (or equivalent), matching continuous sampling semantics.

If zero valid samples in the round → no Modbus write (unchanged).

### 5. Wiring

`LivePr1InferenceStreamClient` → `LaserDetectSamplingCoordinator.onPr1Frame` → lens_det + zero_point with resolved gate interval.

## Risks / Trade-offs

- **[Risk] More native calls per laser-on** (500ms vs old 4×/2s cap) → busy-drop unchanged; monitor CPU on device.
- **[Risk] Short laser pulse** → fewer samples before OFF finalize; cluster reducer may have 0–1 valid samples.
- **[Risk] Burst never exits** → continues at 100ms until laser OFF.
- **[Trade-off] Both modules at 500ms** → may contend on `libai.so`; existing busy-drop mitigates.

## Migration Plan

1. Change `LIVE_WELD` constant + tests referencing 2000ms.
2. Coordinator + burst; PR1-driven zero_point; finalize on laser OFF.
3. Device smoke: short laser window, burst recovery, correction write on laser OFF.

## Open Questions

- Should burst re-enter on a later `-5` after exit? **Default: yes.**
