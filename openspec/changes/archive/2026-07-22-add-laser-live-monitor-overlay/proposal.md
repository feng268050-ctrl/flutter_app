## Why

Engineer Mode already auto-opens a gun-triggered “real-time machine status” overlay that is gauges-only, while Quick Mode welding pages run the same detect pipeline but lack that auto overlay. Operators need a unified Live Monitor experience (local PR1 preview + AI boxes + compact gauges) aligned with the phone Monitor app, without changing Laser Enable / CNC / recording flows.

## What Changes

- Replace the Machine Status overlay body with a shared **Laser Live Monitor** fragment: MediaMTX PR1 `TextureView` + `DetectionOverlayView` + compact machine gauges sidebar.
- Keep existing gun-edge open/close timing on Engineer Mode (`WorkStatusDialogBuilder` + `MachineStatusOverlay.show(..., showConfirm=false)`); body upgrade applies automatically.
- Add the same gun-edge auto overlay to Quick Mode welding pages (`GeneralOperationsFragment`), reusing `WorkStatusDialogBuilder`.
- **Keep** Quick Mode “More Monitor” (device logo) manual entry with confirm bar (`show(..., true)`), opening the **same** Live Monitor body.
- Subscribe overlay to `StreamDetectResultBus` / MemoryCache only — do **not** start/stop the detect pipeline from the overlay.
- Explicitly **exclude** CNC Cut and related CNC UI from this change.
- Update `MachineStatusOverlayPreloader` for the new layout; deprecate in-overlay use of gauges-only `MachineStatusDialogFragment` (cleanup optional follow-up).

## Capabilities

### New Capabilities

- `laser-live-monitor-overlay`: Shared FrostDialog body for Live Monitor (PR1 + detection boxes + gauges), gun-triggered and More-Monitor entry semantics, lifecycle/stop-safe preview.

### Modified Capabilities

- `quick-mode-more-monitor-glass-cards`: Manual More Monitor entry remains, but body becomes Live Monitor (same fragment as gun path) instead of gauges-only machine status content where applicable.

## Impact

- UI: `MachineStatusOverlay`, new `LaserLiveMonitorOverlayFragment` + layout, `WorkStatusDialogBuilder` consumers, `GeneralOperationsFragment`, `EngineerModeActivity` (minimal), `MachineStatusOverlayPreloader`.
- Media: EasyPlayer / MediaMTX **PR1** preview only inside overlay (async stop on dismiss).
- Detect: read-only subscription to `StreamDetectResultBus` (and optional HUD from existing overlay state); `LivePr1InferenceStreamCoordinator` / native pipeline ownership unchanged.
- Out of scope: CNC, Modbus Laser Enable gates, Recording Work checkbox, phone HTTP `/v1/monitor/stat` and `/v1/camera/ai` inside overlay, full `AiVisionFragment` feature set.
