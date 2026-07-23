## Why

Today zero_point waits **500ms after laser ON** before the first native call, while lens_det can run on the **first PR1 I420 frame**. That misalignment wastes the short laser-on window (often &lt;500ms in auto flows) and causes `validSamples=0` even when PR1 is already streaming. Separately, when either module returns **`code=-5` (FRAME_REJECTED)**—overexposure for lens_det or spot-size rejection for zero_point—the fixed gates are too slow to recover once lighting stabilizes. lens_det's **2000ms** live interval is also slower than zero_point's **500ms**, adding unnecessary asymmetry on the shared PR1 path.

## What Changes

- **zero_point first sample on PR1**: Replace timer-only scheduling (`T₀+500ms` … `T₀+2000ms`) with PR1-driven sampling—first attempt on the first acceptable PR1 frame after laser rising edge.
- **Remove four-sample cap**: zero_point SHALL sample continuously while laser is ON (500ms gate), like lens_det; **finalize aggregate / Modbus write on laser OFF** (not after a fixed fourth attempt).
- **lens_det LIVE_WELD → 500ms**: Change normal live PR1 stain-detect interval from **2000ms** to **500ms** (burst and other paths unchanged).
- **Shared FRAME_REJECTED burst mode**: When Java parses **`code=-5`** from **either** module on the live PR1 path, both switch to **100ms** until **both** return **`code=0`**; then restore normal **500ms** gates.
- **Coordinator / gate plumbing**: Centralize burst state (enter, exit, laser-off reset) and logcat mode transitions.
- **Specs & tests**: Update scheduling, aggregate-on-laser-off, and interval constants.

## Capabilities

### New Capabilities

- `laser-detect-frame-rejected-burst`: Shared burst sampling when either module reports `FRAME_REJECTED` (`code=-5`); 100ms interval until both modules succeed.

### Modified Capabilities

- `zero-point-detect-on-laser-on`: PR1-driven continuous sampling while laser ON; no four-sample cap; finalize on laser OFF.
- `lens-det-app-inference`: `LIVE_WELD` 500ms; burst integration unchanged.
- `ai-frame-sampling-inference`: `LIVE_WELD` value 500ms; add `FRAME_REJECTED_BURST` (100ms).

## Impact

- **Java**: `ZeroPointDetectCoordinator`, `ZeroPointDetectTaskSchedule` (remove or repurpose), `OpencvStainDetectCoordinator`, `AiFrameSamplingInterval.LIVE_WELD`, aggregate finalize trigger on laser OFF.
- **Specs**: `zero-point-detect-on-laser-on`, `lens-det-app-inference`, `ai-frame-sampling-inference`.
- **Non-goals**: Native algorithm changes; AI Vision live / process-video intervals.
- **Deploy**: Java-only (`make sync`).
